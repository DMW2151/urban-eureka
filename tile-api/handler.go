package tiles

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	ttlcache "github.com/ReneKroon/ttlcache/v2"
	"github.com/aws/aws-xray-sdk-go/xray"
	"github.com/gorilla/mux"
	log "github.com/sirupsen/logrus"
)

// Define Geographic Constants - Both are *ROUGH* assumptions to get the math to fall in line.
const (
	mercatorW          = 20037500.00 // Constant Width for Mercator Projection
	oneDegreeLngApprox = 111020.00   // Approximation of  # of Meters  == 1 degree of latitude at Equator
)

// Define default vars needed for handler
var (
	// 1. Initialize a dummy context for Redis/v8 (note, Redis/v7 does not require this context!)
	// 2. Initialize cache used by `github.com/ReneKroon/ttlcache/v2`
	ctx, _                        = context.WithCancel(context.Background())
	notFound                      = ttlcache.ErrNotFound
	cache    ttlcache.SimpleCache = ttlcache.NewCache()
	queryMap                      = map[BaseLayer]string{
		point:   OSMPtsQry,
		roads:   OSMRoadsQry,
		polygon: OSMPolygonQry,
		line:    OSMLinesQry,
	}
)

// PBFHandler - Parameters used to open connections to the database && cache
// when handling requests...
type PBFHandler struct {
	DBcfg   *DBPoolConfig          // Args passed to sql.DB to connect to DB
	Ccfg    *CacheConfig           // Args passed to redis.Client to connect to Cache
	Options map[string]interface{} // Extra handler args e.g. CacheTTL, CacheLimit, etc...
}

// stageTileRequest - Converts a request to the relevant geographic parameters
// to send to DB for tile-generation
//
// Geographic bounds from tile coordinates, XYZ tile coordinates
// are in "image space" e.g. origin is top-left, not bottom right,
// stageTileRequest() handles all calculations of X,Y,Z -> Envelope bounds
func (h *PBFHandler) stageTileRequest(r *http.Request) (*TileRequest, error) {

	var tfos = &TagFilterOptions{}

	// Parse out variables from the request
	rV := mux.Vars(r)

	// Check the request for a query param named `filter`; if does exist, augment `tfos`
	// with that string and have the tfos object decode the string using internal methid...
	filterEncodedQry := r.URL.Query().Get("filter")
	if filterEncodedQry != "" {

		tfos.Encoded = filterEncodedQry
		err := tfos.decode()
		if err != nil {
			// Failed to decode into a valid layer request
			log.WithFields(
				log.Fields{"Error": err, "Query": filterEncodedQry},
			).Error("Failed to Decode Custom Layer Values")
			// If this is unresolvable do not send to PostgreSQL to try to sort out!!
			return &TileRequest{}, err
		}
	}

	// Take the Incoming Request; Parse for X,Y,Z values
	Z, errZ := strconv.ParseFloat(rV["z"], 64)
	X, errX := strconv.ParseFloat(rV["x"], 64)
	Y, errY := strconv.ParseFloat(rV["y"], 64)
	layer := rV["layer"]

	switch b := BaseLayer(layer); b {
	case point, polygon, line, roads: // Do Nothing - This is a Valid Request

		if errZ != nil || errX != nil || errY != nil {
			// The request was not formatted properly, must have X, Y, Z -> Return 400
			err := errors.New("Bad Request: Invalid X/Y/Z Request")

			log.WithFields(
				log.Fields{"X": X, "Y": Y, "Z": Z},
			).Error(err)

			return &TileRequest{}, err
		}

		// Check values for the X, Y, Z coords make sense -> X,Y *MUST* be on [0, 2^Z]
		if X > math.Pow(2, Z) || X < 0 || Y > math.Pow(2, Z) || Y < 0 {

			// The request was not formatted properly, must have X, Y, Z -> Return 400
			err := errors.New("Bad Request: X and Y MUST be between (0, 2^Z)")

			log.WithFields(
				log.Fields{"X": X, "Y": Y, "Z": Z},
			).Error(err)

			return &TileRequest{}, err
		}

	default:
		// The request was not from one of the valid base layers -> Return 400
		err := errors.New("Bad Request: Invalid Base Layer")

		log.WithFields(
			log.Fields{"BaseLayer": b},
		).Error(err)

		return &TileRequest{}, err
	}

	// Run calculations for the X and Y bounds of each tile s.t.
	// tileMercSize is the size of the tile in meters (m)
	//
	// Adjust the tile diameter for segment thresholding/segmentation
	// [TODO] - Finish this adjustment calculation!!!
	n := math.Pow(2, Z)
	tileMercSize := (2 * mercatorW) / n

	latRad := math.Atan(math.Sinh(math.Pi * (1 - (2 * Y / n))))
	oneDegreeLngAdjusted := oneDegreeLngApprox * math.Cos(latRad)

	// Transform the X,Y,Z to envelope Min and Max Points - `segSize` and `polygonThresh`
	// variables modify the size of resturn results
	return &TileRequest{
		xMin:          -mercatorW + tileMercSize*X,
		xMax:          -mercatorW + tileMercSize*(X+1),
		yMin:          mercatorW - tileMercSize*(Y+1),
		yMax:          mercatorW - tileMercSize*Y,
		reqArray:      [3]float64{Z, X, Y},
		segSize:       (tileMercSize / oneDegreeLngAdjusted) * 0.25,
		polygonThresh: (tileMercSize / oneDegreeLngAdjusted) * 0.001,
		table:         layer,
		options:       tfos,
	}, nil
}

// generateTile - Wrapper around the tilegeneration SQL script, returns a tile
// also checks the cache to speed things up where possible...
func (h *PBFHandler) generateTile(ctx context.Context, treq *TileRequest) (*TileResponse, error) {

	var (
		tresp      = &TileResponse{}
		qry        *string
		err        error
		conditions = []string{}
	)

	// Cache the result of the TileResponse into Redis - Only Cache if No Error
	// Start Timer for Debugging
	defer func() {
		if c, ok := h.Options["REDIS__USE_CACHE"]; ok {
			if c.(bool) && (err == nil) {
				xray.Capture(ctx, "tiles-api.redis-set", func(ctx context.Context) error {
					// [X_RAY] Cache to Redis
					// Would be nice if this could be async, oh well, not worth the hassle...
					h.setCache(ctx, treq, tresp)
					return nil
				})

			}
		}
	}()

	// Execute request using the min X,Y -> max X,Y box, segment overflow size, and
	// tile precision (polygonThresh params), scan result into response body...
	layer := BaseLayer(treq.table)
	if q, ok := queryMap[layer]; ok {
		qry = &q
	} else {
		// [TODO] This should be unreachable - if happens => bug in the layer validation
		return tresp, err
	}

	// For standard layers - the above switch statement prepares the query - For others,
	// we must prepare the options - this can be cached locally
	//
	// Check the Local Cache...
	// A local hit will happen when the layer is the same, but there is no direct
	// tile cache hit
	//
	// For example `/1/1/1?filter=123` will allow the local cache to hit for all
	// requests like `/{z}/{x}/{y}?filter=123` by way of the shared `filter` val...
	if len(treq.options.Options) > 0 {

		if val, err := cache.Get(fmt.Sprintf("%s/%s", treq.table, treq.options.Encoded)); err != notFound {
			fmtQry := val.(string)
			qry = &fmtQry
		} else {
			// Iterate over options and insert into query...
			conditions = make([]string, len(treq.options.Options))
			for i, tfo := range treq.options.Options {
				conditions[i] = tfo.fmtClause()
			}

			fmtQry := fmt.Sprintf(*qry, strings.Join(conditions, "\n"))
			qry = &fmtQry
			cache.Set(
				fmt.Sprintf("%s/%s", treq.table, treq.options.Encoded),
				fmtQry,
			)
		}

	} else {
		fmtQry := fmt.Sprintf(*qry, "AND true")
		qry = &fmtQry
	}

	// [START SUBSEGMENT - Query Execution]
	err = h.DBcfg.dbPool.QueryRowContext(
		ctx, *qry, // [X_RAY]
		treq.xMin, treq.yMin, treq.xMax, treq.yMax, treq.segSize, treq.polygonThresh,
	).Scan(&tresp.Content)

	// Somewhat concerning error...this shouldn't happen
	// [TODO] Handle for each of these cases...
	//  - Maybe the Table Doesn't Exist.... (500? 404?)
	//  - Maybe an Internal Server Error (500) - Created a Table w.o a geometry column...
	//  - Maybe No rows fetched - Which is itself a 500? (above)
	if err != nil {
		log.WithFields(
			log.Fields{"Tile": treq.getCacheID(), "Error": err},
		).Errorf("Failed to Generate Tile")
		return tresp, err
	}

	return tresp, nil
}

func (h *PBFHandler) setCache(ctx context.Context, treq *TileRequest, tresp *TileResponse) {

	// Check Conditions for caching, if tile too large then do not cache
	if limit, ok := h.Options["REDIS__CACHE_LIMIT_BYTES"]; ok {
		if len(tresp.Content) > limit.(int) {
			log.WithFields(log.Fields{
				"Content-Length": len(tresp.Content),
				"Tile":           treq.getCacheID(),
				"Limit":          limit.(int),
			}).Warnf(
				"Not Caching: Response Too Large",
			)
			return
		}
	}

	// Cache Tile to Redis - Check the TTL
	if ttl, ok := h.Options["REDIS__CACHE_TTL"]; ok {

		// Duration Quoted in NanoSeconds * 1000^3 -> Micro -> Milli -> Regular
		err := h.Ccfg.cachePool.Set(
			ctx, treq.getCacheID(), tresp.Content,
			time.Duration((ttl).(int)*1000*1000*1000),
		).Err()

		if err != nil {
			// Failed to Cache for a TTL Related Reason...
			log.WithFields(
				log.Fields{"Tile": treq.getCacheID(), "Error": err},
			).Errorf("Failed to Cache Tile")
			return
		}

	} else {
		// Use Default Cache Length of 1 hr
		// Duration Quoted in NanoSeconds * 1000^3 -> Micro -> Milli -> Regular
		err := h.Ccfg.cachePool.Set(
			ctx, treq.getCacheID(), tresp.Content, 60*60*1000*1000*1000,
		).Err()

		if err != nil {
			// Failed to Cache For Some Mysterious Reason...
			log.WithFields(
				log.Fields{"Tile": treq.getCacheID(), "Error": err},
			).Errorf("Failed to Cache Tile")
			return
		}
	}
	return
}

// Returns a tile if and only if it's in the redis cache...
func (h *PBFHandler) checkCache(ctx context.Context, treq *TileRequest) (*TileResponse, error) {

	// Init an empty tile - most requests will end up being empty
	var tresp = &TileResponse{}

	// Attempt to get from Cache
	res, err := h.Ccfg.cachePool.Get(
		ctx, treq.getCacheID(),
	).Result()

	// Run of the Mill Cache Miss..
	if (err != nil) && err.Error() == "redis: nil" {
		return tresp, err
	}

	// [TODO][WARN] Handle for mysterious cancellation mid-request!
	if (err != nil) && (ctx.Err() != nil) {
		return tresp, ctx.Err()
	}

	// Some Other Error - Probably Bad
	if err != nil {
		// Log Cache Err - Most often this is `Error Fetching From Cache  - Context Cancelled`
		log.WithFields(
			log.Fields{"Tile": treq.getCacheID(), "Error": err},
		).Errorf("Error Fetching From Cache")
		return tresp, err
	}

	// Set content of response to content from cache...
	tresp.Content = []byte(res)

	return tresp, nil
}

// JSONError
func JSONError(w http.ResponseWriter, errStr string, code int) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(code)

	var e = struct {
		Error string
		Code  int
	}{
		Error: errStr,
		Code:  code,
	}

	json.NewEncoder(w).Encode(e)
}

// HandleTileRequests -
func (h *PBFHandler) HandleTileRequests(w http.ResponseWriter, r *http.Request) {

	// Set Vars...
	var (
		tileRequest  = &TileRequest{}  // Generate this from `stageTileRequest`
		tileResponse = &TileResponse{} // Get this from `checkCache` or `generateTile`
		err          error
	)

	// [TODO] Set response headers - could assign these custom for each resp result...
	// let's leave them here for now though...
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Content-Type", "application/x-protobuf")
	w.Header().Set("Cache-Control", "public,max-age=30")

	// Prepare the Request - Convert /z/x/y coords from the request to an envelope
	// in lat, lng space If the request cannot be prepared for any of the reeasons
	// in `stageTileRequest` -> Return 4XX
	xray.Capture(r.Context(), "tiles-api.internal-stage-request", func(ctx context.Context) error {
		tileRequest, err = h.stageTileRequest(r) // [X_RAY] Stage Request
		return err
	})

	if err != nil {
		// Log error && the bad request variables - could not prepare request
		requestVars := mux.Vars(r)
		log.WithFields(
			log.Fields{"Request Vars": fmt.Sprintf("%s", requestVars), "Error": err},
		).Errorf("Could Not Prepare Tile Request")

		// Return 4XX
		JSONError(w, err.Error(), http.StatusBadRequest)
		return
	}

	if useCache, ok := h.Options["REDIS__USE_CACHE"]; useCache.(bool) && ok {
		xray.Capture(r.Context(), "tiles-api.redis-read", func(ctx context.Context) error {
			tileResponse, err = h.checkCache(ctx, tileRequest)
			return nil
		})
	}

	if (err != nil) && err.Error() != "redis: nil" {
		// Something unrecoverable happened with context - Try Again!
		log.WithFields(
			log.Fields{"Tile": tileRequest.getCacheID(), "Error": err},
		).Error("Request Context Cancelled")

		http.Error(
			w, http.StatusText(http.StatusInternalServerError),
			http.StatusInternalServerError,
		)
		return
	}

	// Case: Cache Hit - Good!
	// Send the content from the cache directly back to ResponseWriter
	if err == nil {
		// Open response block and defer exit to end
		_, seg := xray.BeginSubsegment(r.Context(), "tiles-api.response")
		defer func() {
			seg.Close(nil)
		}()

		_, err := w.Write(tileResponse.Content)

		if err != nil {
			// [WARN]: Ideally We do NOT return an error, unwind, and treat this as a cache miss, but already
			// wrote some content to the buffer, probably not recoverable :(
			log.WithFields(
				log.Fields{"Tile": tileRequest.getCacheID()},
			).Error("Error Fetching From Cache")

			// flush?? flushing might remediate the partially failed write?
			if f, ok := w.(http.Flusher); ok {
				f.Flush()
			}

			// Return 5XX
			http.Error(
				w, err.Error(), http.StatusInternalServerError,
			)
		}
		return
	}

	// Case: Cache Miss - Generate From PostgreSQL
	tileResponse, err = h.generateTile(r.Context(), tileRequest)

	// Open response block and defer exit to end
	_, seg := xray.BeginSubsegment(r.Context(), "tiles-api.response")
	defer func() {
		seg.Close(nil)
	}()

	if err != nil {
		// If there is an Error - We're S.O.L on this tile - Log
		log.WithFields(
			log.Fields{"Tile": tileRequest.getCacheID(), "Error": err},
		).Error("Error Generating Tile")

		// Return 500  - No Clue What Happened
		http.Error(
			w, http.StatusText(http.StatusInternalServerError),
			http.StatusInternalServerError,
		)
		return
	}

	// Case: Cache Miss - Generated From PostgreSQL
	// The response over the return limit - do not render until the user scrolls in!!
	// hope the db index stays hot and when they zoom in the re-generation is fast
	if limit, ok := h.Options["API__RETURN_LIMIT_BYTES"]; ok {

		if len(tileResponse.Content) > limit.(int) {
			log.WithFields(log.Fields{
				"Content-Length": len(tileResponse.Content),
				"Tile":           tileRequest.getCacheID(),
				"Limit":          limit.(int),
			}).Warn(
				"Not Returning Tile: Response Too Large",
			)

			// Write Nothing - Still Get a 200 though...
			_, _ = w.Write([]byte{})
			return
		}
	}

	// Case: Cache Miss - Generated tile from PostgreSQL - Great!
	// Response is between 0 and the bytes imit; send the user a 200 and the content!
	if len(tileResponse.Content) > -1 {
		_, _ = w.Write(tileResponse.Content)
		return
	}
}
