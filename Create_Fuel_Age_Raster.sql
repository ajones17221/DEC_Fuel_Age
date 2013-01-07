CREATE TABLE fuel_age_raster AS
  SELECT 1 AS rid, ST_AsRaster((
       SELECT
          ST_Collect(geom)
       FROM fuel_age
       ), 1000.0, 1000.0 )
  AS rast;