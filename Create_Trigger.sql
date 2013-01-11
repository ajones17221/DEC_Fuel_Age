CREATE OR REPLACE FUNCTION calc_fuel_age() RETURNS trigger as $$
DECLARE
	cur_rec 	RECORD;		--cursor variable
	cur_geom 	VARCHAR; 	--current geometry variable
BEGIN
	IF (TG_OP = 'INSERT') THEN
		-- Check for intersecting polygons, if there aren't any just insert the record into fuel_history
		IF EXISTS (SELECT * FROM fuel_age_test AS a JOIN dec_fire_history_test AS b ON ST_Intersects(a.geom, b.geom) WHERE b.gid = new.gid) THEN
			--Insert the new record into fuel_history
			--INSERT INTO fuel_age_test SELECT gid,year1,geom FROM dec_fire_history_test WHERE gid = new.gid;
			--Loop through the intersecting polygons
			FOR cur_rec IN SELECT * FROM fuel_age_test AS a JOIN dec_fire_history_test AS b ON ST_Intersects(a.geom, b.geom) WHERE b.gid = new.gid ORDER BY a.year1 LOOP
				--If the inserted record is older than the intersecting record update the geometry of the intersecting record
				IF new.year1 > cur_rec.year1 THEN
					--Get the geometry of the current record (new geometry - current geometry)
					cur_geom := (SELECT ST_AsText(ST_MULTI(ST_DIFFERENCE(a.geom,b.geom)))
						FROM fuel_age_test AS a, dec_fire_history_test AS b
						WHERE a.gid = cur_rec.gid and b.gid = new.gid);

					--Delete the old current record from fuel_age
					DELETE FROM fuel_age_test WHERE gid = cur_rec.gid;

					--Recreate the current record with the new geometry
					INSERT INTO fuel_age_test VALUES(cur_rec.gid,cur_rec.year1,ST_GeometryFromText(cur_geom,4326));

					--Set cur_geom to null
					cur_geom = null;
				ELSIF new.year1 < cur_rec.year1 THEN
					--Get the geometry of the inserted record (current geometry - new geometry)
					cur_geom := (SELECT ST_AsText(ST_MULTI(ST_DIFFERENCE(b.geom,a.geom)))
						FROM fuel_age_test AS a, dec_fire_history_test AS b
						WHERE a.gid = cur_rec.gid and b.gid = new.gid);

					--Delete the old inserted record from fuel_age
					DELETE FROM fuel_age_test WHERE gid = new.gid;

					--Recreate the inserted record with the new geometry
					INSERT INTO fuel_age_test VALUES(new.gid,new.year1,ST_GeometryFromText(cur_geom,4326));

					--Set cur_geom to null
					cur_geom = null;
				ELSE
					--Get the geometry of the inserted record (current geometry + new geometry)
					cur_geom := (SELECT ST_AsText(ST_MULTI(ST_UNION(a.geom,b.geom)))
						FROM fuel_age_test AS a, dec_fire_history_test AS b
						WHERE a.gid = cur_rec.gid and b.gid = new.gid);

					--Delete the old inserted record from fuel_age
					DELETE FROM fuel_age_test WHERE gid = cur_rec.gid;

					--Recreate the inserted record with the new geometry
					INSERT INTO fuel_age_test VALUES(cur_rec.gid,cur_rec.year1,ST_GeometryFromText(cur_geom,4326));

					--Set cur_geom to null
					cur_geom = null;
				END IF;
			END LOOP;
		ELSE
			INSERT INTO fuel_age_test SELECT gid,year1,geom FROM dec_fire_history_test WHERE gid = new.gid;
		END IF;
	ELSIF (TG_OP = 'UPDATE') THEN
		-- Check for intersecting polygons
		IF EXISTS (SELECT * FROM fuel_age_test AS a JOIN dec_fire_history AS b ON ST_Intersects(a.geom, b.geom) WHERE b.gid = new.gid) THEN
			--Loop through the intersecting polygons
			FOR cur_rec IN SELECT * FROM fuel_age_test AS a JOIN dec_fire_history AS b ON ST_Intersects(a.geom, b.geom) WHERE b.gid = new.gid ORDER BY a.year1 LOOP
				--If the inserted record is older than the intersecting record update the geometry of the intersecting record
				IF new.year1 > cur_rec.year1 THEN
					--DELETE FROM fuel_age_test WHERE gid = cur_rec.gid;
				
					INSERT INTO fuel_age_test SELECT cur_rec.gid,cur_rec.year1,ST_MULTI(ST_DIFFERENCE(a.geom,b.geom))
						FROM fuel_age_test AS a, dec_fire_history_test AS b
						WHERE a.gid = cur_rec.gid and b.gid = new.gid;
				END IF;
			END LOOP;
		END IF;
	ELSIF (TG_OP = 'DELETE') THEN
		-- Check for intersecting polygons (there should always be at least one though)
		IF EXISTS (SELECT * FROM fuel_age_test AS a JOIN dec_fire_history AS b ON ST_Intersects(a.geom, b.geom) WHERE b.gid = new.gid) THEN
			--Loop through the intersecting polygons
			FOR cur_rec IN SELECT * FROM fuel_age_test AS a JOIN dec_fire_history AS b ON ST_Intersects(a.geom, b.geom) WHERE b.gid = old.gid ORDER BY a.year1 LOOP
				--If the deleted record is older than the intersecting record update the geometry of the intersecting record, otherwise just delete the intersecting record
				IF old.year1 > cur_rec.year1 THEN
					UPDATE fuel_age_test SET geom = (SELECT ST_MULTI(ST_UNION(a.geom,ST_DIFFERENCE(a.geom,b.geom)))
						FROM dec_fire_history_test AS b, fuel_age_test AS a
						WHERE a.gid = old.gid and b.gid = cur_rec.gid)
						WHERE gid = cur_rec.gid;
				ELSE
					DELETE FROM fuel_age_test WHERE gid = cur_rec.gid;
				END IF;
			END LOOP;
		END IF;
	END IF;
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;
--*****************************************************************************************************************
CREATE TRIGGER update_test
AFTER UPDATE OR INSERT OR DELETE ON dec_fire_history_test
FOR EACH ROW
EXECUTE PROCEDURE calc_fuel_age();