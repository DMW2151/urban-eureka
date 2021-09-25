package tiles

import (
	b64 "encoding/base64"
	"encoding/json"
	"fmt"
	"strings"

	log "github.com/sirupsen/logrus"
)

// echo '[{"condition": "eq", "tags": ["foo"], "value": "10mph"}]' | base64
// curl -I -XGET 'http://localhost:2151/polygon/11/591/771?filter=W3siY29uZGl0aW9uIjogImVxIiwgInRhZ3MiOiBbImZvbyJdLCAidmFsdWUiOiAiMTBtcGgifV0K'

// echo '[{"condition": "eq", "tags": ["foo"], "value": "30mph"}, {"condition": "oneof", "tags": ["cycle", "cycleway"]}]' | base64
// curl -I -XGET 'http://localhost:2151/polygon/11/591/771?filter=W3siY29uZGl0aW9uIjogImVxIiwgInRhZ3MiOiBbImZvbyJdLCAidmFsdWUiOiAiMzBtcGgifSwgeyJjb25kaXRpb24iOiAib25lb2YiLCAidGFncyI6IFsiY3ljbGUiLCAiY3ljbGV3YXkiXX1dCg=='

// echo '[{"condition": "eq", "tags": ["foo"], "value": "30mph"}, {"condition": "oneof", "tags": ["cycle", "cycleway"]}]' | base64
// curl -I -XGET 'http://localhost:2151/polygon/11/591/771?filter=W3siY29uZGl0aW9uIjogImVxIiwgInRhZ3MiOiBbImZvbyJdLCAidmFsdWUiOiAiMzBtcGgifSwgeyJjb25kaXRpb24iOiAib25lb2YiLCAidGFncyI6IFsiY3ljbGUiLCAiY3ljbGV3YXkiXX1dCg=='

// A good test...
// echo '[{"condition": "oneof", "tags": ["protect_class"]}]' | base64
// W3siY29uZGl0aW9uIjogIm9uZW9mIiwgInRhZ3MiOiBbInByb3RlY3RfY2xhc3MiXX1dCg==
// and then put this in the request in JS `http://localhost:2151/polygon/{z}/{x}/{y}?filter=W3siY29uZGl0aW9uIjogIm9uZW9mIiwgInRhZ3MiOiBbInByb3RlY3RfY2xhc3MiXX1dCg==`

// Equals --
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
	case Equals, NotEquals, GreaterThan, GreaterThanEqual, LessThan, LessThanEqual:
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

	default:
		return "AND True"
	}
}
