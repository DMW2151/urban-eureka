package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/aws/aws-xray-sdk-go/xray"
	"github.com/aws/aws-xray-sdk-go/xraylog"
	tiles "github.com/dmw2151/tiles"
	"github.com/gorilla/mux"
	log "github.com/sirupsen/logrus"
)

var (
	// Initialize the Connection Manager
	pbfHandler = tiles.PBFHandler{
		DBcfg: &tiles.DBPoolConfig{
			NConn:        96,
			NIdleConn:    16,
			ConnLifetime: 30 * time.Minute,
			Host:         os.Getenv("PG__HOST"),
			Port:         os.Getenv("PG__PORT"),
			User:         os.Getenv("PG__USER"),
			DBName:       os.Getenv("PG__DATABASE"),
			SSLMode:      os.Getenv("PG__SSL_MODE"),
		},
		Ccfg: &tiles.CacheConfig{
			Host: os.Getenv("REDIS__HOST"), // localhost
			Port: os.Getenv("REDIS__PORT"), // 6379
			DB:   0,
		},
		Options: map[string]interface{}{
			// [TODO] Get these from vars and parse..
			"REDIS__USE_CACHE":         true,   // os.Getenv("REDIS__USE_CACHE"),
			"REDIS__CACHE_LIMIT_BYTES": 262144, // os.Getenv("REDIS__CACHE_LIMIT_BYTES"),
			"API__RETURN_LIMIT_BYTES":  262144, // os.Getenv("API__RETURN_LIMIT_BYTES"),
			"REDIS__CACHE_TTL":         600,    // os.Getenv("REDIS__CACHE_TTL"),
		},
	}
)

// HealthCheck - A *VERY* minimal route to handle ECS healthchecks!! or any healthcheck
// for that fact...
func HealthCheck(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("OK"))
}

// Init runs before the main() call to save just a little bit of time.
// 	1. Set logging levels && attach logging handlers
//	2. Start Redis an Db connections
func init() {

	// Set logging config conditional on the environment - Always to STDOUT
	// and always with a specific time & msg format...
	log.SetOutput(os.Stdout)

	log.SetFormatter(&log.TextFormatter{
		FullTimestamp:   true,
		TimestampFormat: "2006-01-02 15:04:05.0000",
	})

	// Configure XRay Tracing
	xray.Configure(xray.Config{
		DaemonAddr:     os.Getenv("AWS_XRAY__HOST"),        // default 127.0.0.1:2000
		ServiceVersion: os.Getenv("AWS_XRAY__SVC_VERSION"), // Version 3.3.3
	})

	// [TODO]: Set this to be configurable...
	xray.SetLogger(
		xraylog.NewDefaultLogger(os.Stdout, xraylog.LogLevelInfo),
	)

	// Env specific environment variables, this `AWS_EXECUTION_ENV` will exist
	// by default on AWS, and allows local mock of AWS environment....
	if env := os.Getenv("AWS_EXECUTION_ENV"); env == "LOCAL" {
		// IF ON AWS -> Then INFO Level && No Caller Info
		log.SetLevel(log.DebugLevel)
		log.SetReportCaller(true)

		// Log Level Cfg
		log.WithFields(log.Fields{
			"Level":             log.DebugLevel,
			"AWS_EXECUTION_ENV": env,
			"Report Caller":     true,
		}).Info("Set Logging Level")

	} else {
		// IF NOT ON AWS -> Then DEBUG Level and activate report caller
		log.SetLevel(log.InfoLevel)
		log.SetReportCaller(false)

		// Log Level Cfg
		log.WithFields(log.Fields{
			"Level":             log.InfoLevel,
			"AWS_EXECUTION_ENV": env,
			"Report Caller":     false,
		}).Info("Set Logging Level")
	}

	// Open DB Conn
	err := pbfHandler.DBcfg.OpenPool()
	if err != nil {
		// Quite simply nothing to do put panic if there is no db connection - Maybe the DB will be stable
		// for the next container
		log.WithFields(log.Fields{
			"Error": err,
		}).Fatal("Failed to Connect to PGSQL - Exiting")
	}

	// Open Redis Connection if cache is enabled...
	// [WARN] HIGHLY recommended to use cache! Disabling cache would ONLY make sense
	// for testing
	if v, _ := pbfHandler.Options["REDIS__USE_CACHE"]; v.(bool) {
		// Initialize Context for redis/v8 client lib
		ctx, _ := context.WithCancel(context.Background())
		err := pbfHandler.Ccfg.OpenConnection(ctx)

		if err != nil {
			// Log Failure
			log.WithFields(log.Fields{
				"Redis Connection Info": fmt.Sprintf("%s:%s", pbfHandler.Ccfg.Host, pbfHandler.Ccfg.Port),
				"Error":                 err,
			}).Error("Error Connecting to Redis")

			// Persist - Reluctantly without Cache...
			log.WithFields(
				log.Fields{
					"Comment": fmt.Sprintf("`REDIS__USE_CACHE` set to `%v`", v.(bool)),
				},
			).Error("Not using tile cache - DB will receive redundant tile requests")
		}

	} else {
		// Log this awful choice...
		log.WithFields(
			log.Fields{
				"Comment": fmt.Sprintf("`REDIS__USE_CACHE` set to `%v`", v.(bool)),
			},
		).Warn("Bad Choice! Not using tile cache - DB will receive redundant tile requests")

	}

}

func main() {

	// Flags for Graceful Shutdown...
	var wait time.Duration

	flag.DurationVar(
		&wait, "graceful-timeout", time.Second*15,
		"The duration for which the server will wait for connections to exit",
	)
	flag.Parse()

	// Init router and define routes for the API
	router := mux.NewRouter().StrictSlash(true)

	// Serves `/<layer>/<x>/<y>/<z>` where:
	// 	* `<layer>` is the name of a user uploaded layer
	// 	*  `<x>`, `<y>`, `<z>` are the coordinates to the tile
	h := xray.Handler(
		xray.NewFixedSegmentNamer("tiles-api"),
		http.HandlerFunc(pbfHandler.HandleTileRequests),
	)

	router.Path("/{layer}/{z:[0-9]+}/{x:[0-9]+}/{y:[0-9]+}").
		Handler(h).Methods("GET")

	// Serves...
	router.Path("/{layer}/{z:[0-9]+}/{x:[0-9]+}/{y:[0-9]+}").
		Queries("filter", "{[a-zA-Z0-9]*?}").
		Handler(h).Methods("GET")

	// HealthCheck - For determining if the container is healthy or not...
	router.Path("/health/").
		HandlerFunc(HealthCheck).
		Methods("GET")

	// Start Service!
	// Graceful Shutdown - Boosted from the Mux Docs - https://github.com/gorilla/mux#graceful-shutdown
	srv := &http.Server{
		Addr: "0.0.0.0:2151",
		// Good practice to set timeouts to avoid Slowloris attacks.
		WriteTimeout: time.Second * 15,
		ReadTimeout:  time.Second * 15,
		IdleTimeout:  time.Second * 60,
		Handler:      router, // Pass our instance of gorilla/mux in.
	}

	go func() {
		// Only expect this when a spot instance terminates or on manual restart
		if err := srv.ListenAndServe(); err != nil {
			log.WithFields(log.Fields{"Error": err}).Error("API Exited")
		}
	}()

	// Exit condition for Spot Instance termination or kill locally...
	// We'll accept graceful shutdowns when quit via SIGINT. But SIGKILL,
	// SIGQUIT or SIGTERM (Ctrl+/) will not be caught.
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)

	// Block until we receive our signal.
	<-c

	// Create a deadline to wait for.
	exitContext, cancel := context.WithTimeout(
		context.Background(), wait,
	)

	defer cancel()

	// Doesn't block if no connections, but will otherwise wait until the timeout deadline.
	srv.Shutdown(exitContext)
	log.Info("API shutting down gracefully")

	os.Exit(0)
}
