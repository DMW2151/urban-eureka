package tiles

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-xray-sdk-go/xray"

	// Unamed Import of lib/pq Required for Postgres Driver
	_ "github.com/lib/pq"
	log "github.com/sirupsen/logrus"
)

// DBPoolConfig - Config for db.SQL ConnectionPool
// 		NConn, NIdleConn, ConnLifetime, etc. -> All define how to manage unique connections to the DB in the pool
// 		Host, Port, User, DBName, SSLMode ->  DB connection string options
// 		dbPool -> Connection pool
type DBPoolConfig struct {
	NConn, NIdleConn                  int
	ConnLifetime                      time.Duration
	Host, Port, User, DBName, SSLMode string
	dbPool                            *sql.DB
}

// OpenPool - Validates the options passed to `DBPoolConfig` and opens a connection the DB
func (dbcfg *DBPoolConfig) OpenPool() (err error) {

	// Define DB
	var db *sql.DB

	// Validate the SSL Mode is from expected list for PostgreSQL...
	// [NOTE] - TBH, not sure why I do this check here...
	validSSLModes := map[string]bool{
		"require":     true,
		"verify-full": true,
		"verify-ca":   true,
		"disable":     true,
	}

	if _, ok := validSSLModes[dbcfg.SSLMode]; !ok {
		err = errors.New("Invalid SSL Mode")

		// Can't connect to DB!!
		log.WithFields(
			log.Fields{
				"SSL Mode": dbcfg.SSLMode,
				"Error":    err,
			},
		).Errorf("Cannot Connect to PGSQL")

		return err
	}

	// [NOTE]: Throws error if and only if psqlInfo is invalid. Does not
	// attempt to make connection.
	if env := os.Getenv("AWS_EXECUTION_ENV"); env == "LOCAL" {
		// Write connectionstr from cfg
		connstr := fmt.Sprintf(
			"host=%s port=%s user=%s dbname=%s sslmode=%s connect_timeout=1",
			dbcfg.Host, dbcfg.Port, dbcfg.User, dbcfg.DBName, dbcfg.SSLMode,
		)

		// Use standard SQL Open to Initialize connection Iff not on AWS
		db, err = sql.Open("postgres", connstr)
		if err != nil {
			// Can't get to DB!!
			log.WithFields(
				log.Fields{
					"Connection Info": connstr,
					"Error":           err,
				},
			).Error("Cannot Connect to PGSQL")
			return err
		}

		// Check to see if the x-ray agent was configured
		log.Info("Init DB connection pool without X-ray Tracing requests")

	} else {

		if dbcfg.Host == "" {
			// [Get From Cloud Map] Check CloudMap

		}

		// [TODO] Change this lack of auth -> for obvious reasons....
		connURL := fmt.Sprintf("postgres://%s:nosecurity@%s:%s/%s?sslmode=%s",
			dbcfg.User, dbcfg.Host, dbcfg.Port, dbcfg.DBName, dbcfg.SSLMode,
		)

		db, err = xray.SQLContext("postgres", connURL)

		if err != nil {
			log.WithFields(
				log.Fields{"Connection Info": connURL, "Error": err},
			).Error("Cannot Connect to PGSQL")
			return
		}

		// Successful Connection...
		log.WithFields(
			log.Fields{"Connection Info": connURL},
		).Info("Init DB connection pool with X-ray Tracing requests")
	}

	// NOTE: See note above: `sql.Open()`` does not attempt to connect,
	// call db.ping() to verify connection. If this is valid, the returned
	// DB is safe for concurrent use by multiple goroutines && maintains
	// its own connection pooling

	// [NOTE] db.Ping() preferred for this type of communication, however the
	// x-ray client requires context passed w. all calls...
	// [OLD] err = db.Ping()

	// Use *ALMOST* as normal, scanning into a dummy byte slice...
	var ping int64

	// Explicit Call Context w. Cancel...
	cancelContext, cancel := context.WithCancel(context.Background())
	ctx, seg := xray.BeginSegment(cancelContext, "postgresql-init")
	err = db.QueryRowContext(
		ctx, "SELECT 1 as ping;",
	).Scan(&ping)
	cancel()

	seg.Close(nil)

	if err != nil {
		// Log Failed Ping - can't get to DB!!
		log.WithFields(
			log.Fields{"Error": err},
		).Error("Cannot Connect to PGSQL - Failed Ping")
		return err
	}

	// Successful connection -  Initialize DB connection pool with the values
	// from the cfg - https://www.alexedwards.net/blog/configuring-sqldb
	db.SetMaxOpenConns(dbcfg.NConn)
	db.SetMaxIdleConns(dbcfg.NIdleConn)
	db.SetConnMaxLifetime(dbcfg.ConnLifetime)

	// Set dbPool object onto db object itself...
	dbcfg.dbPool = db
	return
}
