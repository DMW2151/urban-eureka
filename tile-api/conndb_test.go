package tiles

import (
	"os"
	"testing"
	"time"

	log "github.com/sirupsen/logrus"
	"github.com/stretchr/testify/assert"
)

// Initialize the DB Connection Pool --
func init() {

	// Set "Correct" env variables - Assumes that PostgreSQL
	// running on localhost w. the following:
	os.Setenv("PG_HOST", "localhost")
	os.Setenv("PG_USER", "def")
	os.Setenv("PG_PORT", "5432")
	os.Setenv("PG_DATABASE", "defaultdb")
	os.Setenv("SSL_MODE", "disable")

	// Set Logging Config
	log.SetOutput(os.Stdout)
	log.SetLevel(log.DebugLevel)

	log.SetReportCaller(false)

	log.SetFormatter(&log.JSONFormatter{
		TimestampFormat: "2006-01-02 15:04:05.0000",
	})

}

func TestOpenDBConnPool(t *testing.T) {

	// Set Parallel Runs...
	t.Parallel()

	// Expect this to Timeout...
	t.Run("validPool", func(t *testing.T) {
		db := &DBPoolConfig{
			NConn:        10,
			NIdleConn:    10,
			ConnLifetime: time.Minute,
			Host:         os.Getenv("PG_HOST"),
			Port:         os.Getenv("PG_PORT"),
			User:         os.Getenv("PG_USER"),
			DBName:       os.Getenv("PG_DATABASE"),
			SSLMode:      os.Getenv("SSL_MODE"),
		}

		err := db.OpenPool()
		assert.Nil(t, err)
	})

	t.Run("invalidPoolHost", func(t *testing.T) {
		// Set Expected Error
		expectedErrorSubstring := "^dial tcp .* i/o timeout$"

		db := &DBPoolConfig{
			NConn:        10,
			NIdleConn:    10,
			ConnLifetime: time.Minute,
			Host:         "127.0.0.2", // This is not localhost
			Port:         os.Getenv("PG_PORT"),
			User:         os.Getenv("PG_USER"),
			DBName:       os.Getenv("PG_DATABASE"),
			SSLMode:      os.Getenv("SSL_MODE"),
		}

		err := db.OpenPool()

		// This should throw an Error
		assert.NotNil(t, err)

		// That Error Should be an IO/Timeout Error
		assert.Regexp(t,
			expectedErrorSubstring,
			err.Error(),
			"expected error matching %q, got %s",
			expectedErrorSubstring,
			err.Error(),
		)

	})

	t.Run("invalidPoolUser", func(t *testing.T) {
		db := &DBPoolConfig{
			NConn:        10,
			NIdleConn:    10,
			ConnLifetime: time.Minute,
			Host:         os.Getenv("PG_HOST"),
			Port:         os.Getenv("PG_PORT"),
			User:         "thisuserisfake", // This User Does Not Exist...
			DBName:       os.Getenv("PG_DATABASE"),
			SSLMode:      os.Getenv("SSL_MODE"),
		}

		err := db.OpenPool()
		assert.NotNil(t, err)

	})

	t.Run("invalidDatabase", func(t *testing.T) {
		db := &DBPoolConfig{
			NConn:        10,
			NIdleConn:    10,
			ConnLifetime: time.Minute,
			Host:         os.Getenv("PG_HOST"),
			Port:         os.Getenv("PG_PORT"),
			User:         os.Getenv("PG_USER"),
			DBName:       "thisdbdoesntexist", // This DB Does Not Exist...
			SSLMode:      os.Getenv("SSL_MODE"),
		}

		err := db.OpenPool()
		assert.NotNil(t, err)
	})

	t.Run("invalidPoolSSLMode", func(t *testing.T) {

		expectedErrorSubstring := "^Invalid SSL Mode$"

		db := &DBPoolConfig{
			NConn:        10,
			NIdleConn:    10,
			ConnLifetime: time.Minute,
			Host:         os.Getenv("PG_HOST"),
			Port:         os.Getenv("PG_PORT"),
			User:         os.Getenv("PG_USER"),
			DBName:       os.Getenv("PG_DATABASE"),
			SSLMode:      "enable",
		}

		err := db.OpenPool()

		// Should be Error
		assert.NotNil(t, err)

		// That Error Should be an InvalidSSLMode
		assert.Regexp(t, expectedErrorSubstring,
			err.Error(),
			"expected error matching %q, got %s",
			expectedErrorSubstring,
			err.Error(),
		)
	})

	t.Run("poolSSLModeDoesNotMatch", func(t *testing.T) {

		db := &DBPoolConfig{
			NConn:        10,
			NIdleConn:    10,
			ConnLifetime: time.Minute,
			Host:         os.Getenv("PG_HOST"),
			Port:         os.Getenv("PG_PORT"),
			User:         os.Getenv("PG_USER"),
			DBName:       os.Getenv("PG_DATABASE"),
			SSLMode:      "require",
		}

		// Test Assumes that we already did SSL termination
		err := db.OpenPool()
		assert.NotNil(t, err)
	})

}
