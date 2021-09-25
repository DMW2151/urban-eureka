package tiles

// BaseLayer - One of the four basic OSM types - Point, Line, Roads, Polygon
type BaseLayer string

const (
	point   = "point"
	line    = "line"
	roads   = "roads"
	polygon = "polygon"
)
