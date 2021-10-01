

## Testing - on t2.micro

```bash
# 190MB -> 600MB
wget https://www2.census.gov/geo/tiger/TIGER2020/TABBLOCK20/tl_2020_36_tabblock20.zip &&\
    unzip tl_2020_36_tabblock20.zip -d /data/layers/nyblocks &&\
    rm tl_2020_36_tabblock20.zip

ogr2ogr -overwrite \
        -f "PostgreSQL" PG:"dbname=${POSTGRES_DB} user=${POSTGRES_USER} host=localhost" \
        /data/layers/blocks/ \
        -nln blocks \
        -lco OVERWRITE=yes \
        -t_srs "EPSG:4326" \
        -nlt PROMOTE_TO_MULTI
```

```sql
create table bglines as (
    SELECT
        a.geoid20,
        b.geoid20 as neighbor_geoid,
        st_intersection(
            a.wkb_geometry,
            b.wkb_geometry
        ) as wkb_geometry
    FROM blocks a
    left join blocks b
on ST_Touches(a.wkb_geometry, b.wkb_geometry)::bool);

create index on bglines using gist(wkb_geometry);
```

```bash
CONTAINER ID        NAME                CPU %               MEM USAGE / LIMIT     MEM %               NET I/O             BLOCK I/O           PIDS
a662366b9d26        src_api_1           0.00%               14.89MiB / 978.6MiB   1.52%               38.3kB / 39.2kB     118MB / 0B          12
e2320dd4b895        src_db_1            89.56%              22.07MiB / 978.6MiB   2.26%               1.04GB / 7.33MB     1.55GB / 1.44GB     11
```
