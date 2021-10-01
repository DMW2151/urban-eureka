package tiles

import (
	"fmt"
)

// TileRequest -
type TileRequest struct {
	xMin, xMax, yMin, yMax float64
	segSize                float64
	polygonThresh          float64
	reqArray               [3]float64
	err                    error
	table                  string
	options                *TagFilterOptions
}

func (treq *TileRequest) getCacheID() string {
	return fmt.Sprintf(
		"/%s/%.0f/%.0f/%.0f/%s",
		treq.table,
		treq.reqArray[0],
		treq.reqArray[1],
		treq.reqArray[2],
		treq.options.Encoded,
	)
}

// TileResponse -
type TileResponse struct {
	Content []byte
}
