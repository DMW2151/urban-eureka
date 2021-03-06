package tiles

// TODO: `LIMIT` is crude - refine these to return fixed point numbers!

// OSMPtsQry -
var OSMPtsQry string = `SELECT ST_AsMVT(a1.*) as pbf FROM (
	SELECT 
		ST_AsMVTGeom(
			st_segmentize(st_simplify(ST_TRANSFORM(c2.way, 4326), $6, false), $5), 
			st_transform(ST_MakeEnvelope($1, $2, $3, $4, 3857), 4326),
			extent=>4096, 
			buffer=>256
		) AS geom, osm_id, tags
	FROM osm.osm_point c2
	WHERE c2.way && ST_MakeEnvelope($1, $2, $3, $4, 3857)
	%s
	ORDER BY RANDOM()
	LIMIT 500
) a1;`

// OSMLinesQry -
var OSMLinesQry string = `SELECT ST_AsMVT(a1.*) as pbf FROM (
	SELECT 
		ST_AsMVTGeom(
			st_segmentize(st_simplify(ST_TRANSFORM(c2.way, 4326), $6, false), $5), 
			st_transform(ST_MakeEnvelope($1, $2, $3, $4, 3857), 4326),
			extent=>4096, 
			buffer=>256
		) AS geom, osm_id, tags
	FROM osm.osm_line c2
	WHERE c2.way && ST_MakeEnvelope($1, $2, $3, $4, 3857)
	%s
	ORDER BY ST_Length(c2.way) DESC
	LIMIT 500
) a1;`

// OSMPolygonQry -
var OSMPolygonQry string = `SELECT ST_AsMVT(a1.*) as pbf FROM (
	SELECT 
		ST_AsMVTGeom(
			st_segmentize(st_simplify(ST_TRANSFORM(c2.way, 4326), $6, false), $5), 
			st_transform(ST_MakeEnvelope($1, $2, $3, $4, 3857), 4326),
			extent=>4096, 
			buffer=>256
		) AS geom, osm_id, tags
	FROM osm.osm_polygon c2
	WHERE c2.way && ST_MakeEnvelope($1, $2, $3, $4, 3857)
	%s
	ORDER BY ST_AREA(c2.way) DESC
	LIMIT 500
) a1;`

// OSMRoadsQry -
var OSMRoadsQry string = `SELECT ST_AsMVT(a1.*) as pbf FROM (
	SELECT 
		ST_AsMVTGeom(
			st_segmentize(st_simplify(ST_TRANSFORM(c2.way, 4326), $6, false), $5), 
			st_transform(ST_MakeEnvelope($1, $2, $3, $4, 3857), 4326),
			extent=>4096, 
			buffer=>256
		) AS geom, osm_id, tags
	FROM osm.osm_roads c2
	WHERE c2.way && ST_MakeEnvelope($1, $2, $3, $4, 3857)
	%s
	ORDER BY ST_Length(c2.way) DESC
	LIMIT 500
) a1;`
