CREATE TRIGGER update_test
AFTER UPDATE OR INSERT OR DELETE ON dec_fire_history_test
FOR EACH ROW
EXECUTE PROCEDURE calc_fuel_age();

CREATE OR REPLACE FUNCTION calc_fuel_age() RETURNS trigger as $update_test$
DECLARE
	id_array integer[];
	cur_id integer;
BEGIN
	RAISE NOTICE 'Begin';
	IF (TG_OP = 'DELETE') THEN
		RAISE NOTICE 'Delete';
		--Select fuel history records that intersect with the deleted fire history polygon
		SELECT a.gid INTO id_array
			FROM fuel_age_test AS a
			JOIN dec_fire_history_test AS b
			ON ST_Intersects(a.geom, b.geom)
			WHERE b.gid = old.gid
			ORDER BY a.gid;
			
		--Loop through intersecting polys
		RAISE NOTICE 'Array Value',cur_id;
		FOREACH cur_id IN ARRAY id_array 
		LOOP
			RAISE NOTICE 'Loop';
			-- If the intersecting polygon is more recent than the deleted polygon clip it
			IF row_data.year1 < old.year1 THEN
				UPDATE fuel_age_test SET a.geom = (SELECT ST_DIFFERENCE(a.geom,b.geom)
				FROM dec_fire_history_test AS b, fuel_age_test AS a
				WHERE a.gid = row_data.gid and b.gid = old.gid)
				WHERE gid = row_data.gid;
			END IF;
		END LOOP;
	ELSIF (TG_OP = 'UPDATE') THEN
		RAISE NOTICE 'Update';
		--UPDATE fuel_age_test SET fuel_age_test.geom = NEW.geom FROM NEW WHERE fuel_age_test.gid = NEW.gid;
		--DELETE FROM fuel_age_test WHERE fuel_age_test.gid = NEW.gid;
		--INSERT INTO fuel_age_test SELECT * FROM dec_fire_history_test WHERE gid = NEW.gid;
	ELSIF (TG_OP = 'INSERT') THEN
		RAISE NOTICE 'Insert';
		--INSERT INTO fuel_age_test SELECT * FROM dec_fire_history_test WHERE gid = NEW.gid;
	ELSE
		RAISE NOTICE 'Nothing Happened';
	END IF;
RETURN NEW;
END;
$update_test$ LANGUAGE plpgsql;