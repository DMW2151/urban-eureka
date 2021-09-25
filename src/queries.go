package tiles

// OSMPtsQry -
var OSMPtsQry string = `SELECT ST_AsMVT(a1.*) as pbf FROM (
	SELECT 
		ST_AsMVTGeom(
			st_segmentize(st_simplify(ST_TRANSFORM(c2.way, 4326), $6, false), $5), 
			st_transform(ST_MakeEnvelope($1, $2, $3, $4, 3857), 4326),
			extent=>4096, 
			buffer=>256
		) AS geom, osm_id, tags
	FROM public.main_point c2
	WHERE c2.way && ST_MakeEnvelope($1, $2, $3, $4, 3857)
	%s
	ORDER BY RANDOM()
	LIMIT 5000
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
	FROM public.main_line c2
	WHERE c2.way && ST_MakeEnvelope($1, $2, $3, $4, 3857)
	%s
	ORDER BY ROW_NUMBER() OVER()
	LIMIT 1000
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
	FROM public.main_polygon c2
	WHERE c2.way && ST_MakeEnvelope($1, $2, $3, $4, 3857)
	%s
	ORDER BY ROW_NUMBER() OVER()
	LIMIT 1000
) a1;`

// OSMRoadsQry -
var OSMRoadsQry string = `SELECT ST_AsMVT(a1.*) as pbf FROM (
	SELECT 
		ST_AsMVTGeom(
			st_segmentize(st_simplify(ST_TRANSFORM(c2.way, 4326), $6, false), $5), 
			st_transform(ST_MakeEnvelope($1, $2, $3, $4, 3857), 4326),
			extent=>4096, 
			buffer=>256
		) AS geom
	FROM public.main_roads c2
	WHERE c2.way && ST_MakeEnvelope($1, $2, $3, $4, 3857)
	%s
	ORDER BY ROW_NUMBER() OVER()
	LIMIT 1000
) a1;`
