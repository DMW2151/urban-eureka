package tiles

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/servicediscovery"
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

func getDBIPv4() (string, error) {

	// Find the DB...
	svc := servicediscovery.New(
		session.New(&aws.Config{
			Region: aws.String("us-east-1"),
		}),
	)

	input := &servicediscovery.DiscoverInstancesInput{
		HealthStatus:  aws.String("HEALTHY"),
		MaxResults:    aws.Int64(1),
		NamespaceName: aws.String("local"),
		ServiceName:   aws.String("db_svc"),
	}

	instances, err := svc.DiscoverInstances(input)
	if err != nil {
		if aerr, ok := err.(awserr.Error); ok {
			switch aerr.Code() {
			case servicediscovery.ErrCodeServiceNotFound:

				log.WithFields(
					log.Fields{
						"ErrorCode": servicediscovery.ErrCodeServiceNotFound,
						"Error":     aerr.Error(),
					},
				).Error("Cannot find DB SVC")
				return "", aerr

			case servicediscovery.ErrCodeNamespaceNotFound:
				log.WithFields(
					log.Fields{
						"ErrorCode": servicediscovery.ErrCodeNamespaceNotFound,
						"Error":     aerr.Error(),
					},
				).Error("Cannot find DB SVC")
				return "", aerr

			case servicediscovery.ErrCodeInvalidInput:

				log.WithFields(
					log.Fields{
						"ErrorCode": servicediscovery.ErrCodeInvalidInput,
						"Error":     aerr.Error(),
					},
				).Error("Cannot find DB SVC")
				return "", aerr

			default:

				log.WithFields(
					log.Fields{
						"Error": aerr.Error(),
					},
				).Error("Cannot find DB SVC")
				return "", aerr
			}
		}
	}

	// Parse
	for _, inst := range instances.Instances {
		// TODO - This shouldn't be hardcoded -> Maybe connect to one at random instead!
		if *inst.InstanceId == "db_svc_master" {
			if ipv, ok := inst.Attributes["AWS_INSTANCE_IPV4"]; ok {
				return *ipv, nil
			}
		}
	}

	return "", errors.New("Cannot Find DB SVC")
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
			// [Get From Cloud Map] Check CloudMap and Secrets Manager...
			ipv4, err := getDBIPv4()
			if err != nil {
				log.WithFields(
					log.Fields{
						"Error": err,
					},
				).Error("Cannot Connect to PGSQL")
			}

			dbcfg.Host = ipv4
		}

		connURL := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=%s",
			dbcfg.User, os.Getenv("PG__PASSWORD"), dbcfg.Host, dbcfg.Port, dbcfg.DBName, dbcfg.SSLMode,
		)

		db, err = xray.SQLContext("postgres", connURL)

		if err != nil {
			log.WithFields(
				log.Fields{"Error": err},
			).Error("Cannot Connect to PGSQL")
			return
		}

		// Successful Connection...
		log.WithFields(
			log.Fields{"Connection Info": "NULL"},
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
