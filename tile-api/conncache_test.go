package tiles

import (
	"os"
	"testing"

	log "github.com/sirupsen/logrus"
	"github.com/stretchr/testify/assert"
	"golang.org/x/net/context"
)

// Initialize the DB Connection Pool
func init() {

	// Set "Correct" env variables - Assumes that PostgreSQL
	// running on localhost w. the following:
	os.Setenv("REDIS_HOST", "localhost") // Running on Localhost
	os.Setenv("REDIS_PORT", "6379")      // Default Redis Port
	os.Setenv("REDIS_DB", "0")
	os.Setenv("REDISCLI_AUTH", "")

	// Set Logging Config
	log.SetOutput(os.Stdout)
	log.SetLevel(log.DebugLevel)

	log.SetFormatter(&log.JSONFormatter{
		TimestampFormat: "2006-01-02 15:04:05.0000",
	})

}

func TestOpenCacheConnection(t *testing.T) {

	// Set Parallel Runs...
	t.Parallel()

	// Test for Valid Connection...
	t.Run("validConnection", func(t *testing.T) {
		cache := &CacheConfig{
			Host: os.Getenv("REDIS_HOST"),
			Port: os.Getenv("REDIS_PORT"),
			DB:   0,
		}

		err := cache.OpenConnection(context.Background())
		assert.Nil(t, err)
	})

	t.Run("authNotNeeded", func(t *testing.T) {

		// Our DB has no PW Auth, what happens when one is set?
		os.Setenv("REDISCLI_AUTH", "password")

		cache := &CacheConfig{
			Host: os.Getenv("REDIS_HOST"),
			Port: os.Getenv("REDIS_PORT"),
			DB:   0,
		}

		err := cache.OpenConnection(context.Background())
		assert.NotNil(t, err)

		expectedErrorSubstring := "ERR Client sent AUTH"
		assert.Regexp(t, expectedErrorSubstring,
			err.Error(),
			"expected error matching %q, got %s",
			expectedErrorSubstring,
			err.Error(),
		)

	})

}
