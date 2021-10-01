package tiles

import (
	b64 "encoding/base64"
	"encoding/json"
	"fmt"
	"strings"

	log "github.com/sirupsen/logrus"
)

const (
	// Equality
	Equals           optionCondition = "eq"    // "AND (tags -> %s) = %s",
	NotEquals        optionCondition = "noteq" // "AND (tags -> %s) != %s"
	GreaterThanEqual optionCondition = "gte"   // "AND (tags -> %s) >= %s",
	GreaterThan      optionCondition = "gt"    // "AND (tags -> %s) > %s",
	LessThanEqual    optionCondition = "lte"   // "AND (tags -> %s) <= %s",
	LessThan         optionCondition = "lt"    // "AND (tags -> %s) < %s",
	AllExist         optionCondition = "allof" // "AND (tags ?& ARRAY[%v])",
	OneExist         optionCondition = "oneof" // "AND (tags ?| ARRAY[%v])",
	Like             optionCondition = "like"  // "AND (tags -> %s) LIKE %s",
)

type optionCondition string

// TagFilterOption -
type TagFilterOption struct {
	Condition optionCondition `json:"condition"`
	Tags      []string        `json:"tags"`
	Value     string          `json:"value"`
}

// TagFilterOptions -
type TagFilterOptions struct {
	Options []TagFilterOption
	Encoded string
}

func (tfos *TagFilterOptions) decode() (err error) {

	// Decode the String
	sDec, err := b64.StdEncoding.DecodeString(tfos.Encoded)
	if err != nil {
		log.WithFields(
			log.Fields{
				"LayerCode": tfos.Encoded,
				"Error":     err,
			},
		).Errorf("Cannot Decode Layer Filter")
		return
	}

	// Umarshall to JSON
	err = json.Unmarshal(sDec, &tfos.Options)
	if err != nil {
		// Unmarshal Failed - RIP - Very Rare!
		log.WithFields(
			log.Fields{
				"LayerCode": tfos.Encoded,
				"LayerData": tfos.Options,
				"Error":     err,
			},
		).Errorf("Cannot Unmarshal Layer Code into Options")
		tfos.Options = []TagFilterOption{}
		return
	}

	// Log Here...
	return
}

// Formatting....
func (tfo *TagFilterOption) fmtClause() string {
	switch c := tfo.Condition; c {
	case Equals, NotEquals, GreaterThan, GreaterThanEqual, LessThan, LessThanEqual, Like:
		// Value Comp
		// Check that tfo.Tags is a single item array...
		t := tfo.Tags[0]
		return c.fmtValueComp(t, tfo.Value)
	case OneExist, AllExist:
		// Set Comp
		return c.fmtInclusionComp(tfo.Tags)
	default:
		return "AND True"
	}
}

func (oc optionCondition) fmtInclusionComp(tags []string) string {
	switch oc {
	case OneExist:
		strtags := "'" + strings.Join(tags, "', '") + "'"
		return fmt.Sprintf("AND (tags ?| ARRAY[%v])", strtags)
	case AllExist:
		strtags := "'" + strings.Join(tags, "', '") + "'"
		return fmt.Sprintf("AND (tags ?& ARRAY[%v])", strtags)
	default:
		return "AND True"
	}
}

func (oc optionCondition) fmtValueComp(tag string, val string) string {
	switch oc {
	case Equals:
		return fmt.Sprintf("AND (tags -> '%s') = '%s'", tag, val)
	case NotEquals:
		return fmt.Sprintf("AND (tags -> '%s') != '%s'", tag, val)
	case GreaterThanEqual:
		return fmt.Sprintf("AND (tags -> '%s') >= '%s'", tag, val)
	case GreaterThan:
		return fmt.Sprintf("AND (tags -> '%s') > '%s'", tag, val)
	case LessThan:
		return fmt.Sprintf("AND (tags -> '%s') < '%s'", tag, val)
	case LessThanEqual:
		return fmt.Sprintf("AND (tags -> '%s') <= '%s'", tag, val)
	case Like:
		return fmt.Sprintf("AND (tags -> '%s') LIKE '%s'", tag, val)
	default:
		return "AND True"
	}
}
