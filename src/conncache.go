package tiles

import (
	"context"
	"fmt"
	"os"

	redis "github.com/go-redis/redis/v8"
	log "github.com/sirupsen/logrus"
)

var (
	purgeOnStart, _ = os.LookupEnv("REDIS__PURGE_ON_START")
)

// CacheConfig - Defines the connection to Redis instance to use for Tile-Caching
// 	Host - IP or DNS Name of the instance to connect
// 	Port - Port of the instance to connect to -> Assume 6379 unless otherwise specified
// 	DB - DB ID for the layers DB
//  	[TODO] This should be a string to allow reading from os.GetEnv - Not Important for the Moment - Assume DB == 0
// 	cachePool - a redis.Client/ConnectionPool used for managing connections to the instance
type CacheConfig struct {
	Host, Port string
	DB         int
	cachePool  *redis.Client
}

// onConnectRedisHandler - Light wrapper implements redis.OnConnect, this runs on each connection w. a new
// redis instance!
func onConnectRedisHandler(ctx context.Context, cn *redis.Conn) error {

	log.Info("New Redis Client Connection Established")

	if purgeOnStart == "True" || purgeOnStart == "1" || purgeOnStart == "T" {
		// On each new connection - flush the content of the DB to continuously be testing cache...
		// [WARN] NOT RECOMMENDED FOR PRODUCTION
		cn.FlushAll(ctx)

		// Log the Cache Clear Event...
		log.WithFields(
			log.Fields{
				"Comment": fmt.Sprintf("`REDIS__PURGE_ON_START` set to `%s`", purgeOnStart),
			},
		).Warnf("Flushing content of Redis instance")
	}

	return nil
}

// OpenConnection -
func (ccfg *CacheConfig) OpenConnection(ctx context.Context) (err error) {

	// Open client connection pool with basic Redis options
	ccfg.cachePool = redis.NewClient(
		&redis.Options{
			// [TODO] Handle for Port Name and HostName Combinations, e.g on ECS this may just be
			// `redisInstance` and `redisInstance:6379` would not resolve...
			Addr:       fmt.Sprintf("%s:%s", ccfg.Host, ccfg.Port),
			Password:   os.Getenv("REDIS__REDISCLI_AUTH"),
			DB:         ccfg.DB,
			MaxRetries: 5,
			OnConnect:  onConnectRedisHandler,
		},
	)

	// Open Pool && connect to the DB instance
	_, err = ccfg.cachePool.Ping(ctx).Result()
	if err != nil {
		// Log Error - Unexpected
		log.WithFields(
			log.Fields{
				"Error": err,
			},
		).Error("Failed to open Redis connection pool")
		return
	}

	return nil

}
