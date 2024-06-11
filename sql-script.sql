SET TIMEZONE TO 'UTC';

SET check_function_bodies = false;

SET search_path = pg_catalog;

CREATE SCHEMA grabbing;

CREATE SEQUENCE grabbing.account_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE grabbing.face_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE grabbing.host_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE grabbing.map_item_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE grabbing.map_start_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE grabbing.query_itself_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE SEQUENCE grabbing.response_itself_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

CREATE TABLE grabbing.account (
	id bigint NOT NULL,
	username text NOT NULL,
	password_hashed text NOT NULL,
	face_id bigint,
	enabled boolean DEFAULT true NOT NULL
);

CREATE TABLE grabbing.account_role (
	id bigint NOT NULL,
	role_name text NOT NULL
);

CREATE TABLE grabbing.face (
	id bigint NOT NULL,
	face_name text NOT NULL
);

CREATE TABLE grabbing.map_item (
	id bigint NOT NULL,
	object_id bigint NOT NULL,
	map_key text NOT NULL,
	map_value text NOT NULL
);

CREATE TABLE grabbing.map_start (
	id bigint NOT NULL,
	map_name text NOT NULL
);

CREATE TABLE grabbing.query_host (
	id bigint NOT NULL,
	host_name text NOT NULL,
	sampling_frequency bigint NOT NULL,
	last_take timestamp with time zone NOT NULL
);

CREATE TABLE grabbing.query_itself (
	id bigint DEFAULT nextval('grabbing.query_itself_id_seq'::regclass) NOT NULL,
	url text NOT NULL,
	host_id bigint NOT NULL,
	parameters_id bigint NOT NULL,
	headers_id bigint NOT NULL,
	body text NOT NULL,
	is_has_response boolean DEFAULT false NOT NULL,
	response_id bigint,
	face_id bigint NOT NULL,
	enabled boolean DEFAULT true NOT NULL
);

CREATE TABLE grabbing.relationship_account_and_role (
	id bigint NOT NULL,
	account_id bigint NOT NULL,
	role_id bigint NOT NULL
);

CREATE TABLE grabbing.response_itself (
	id bigint DEFAULT nextval('grabbing.response_itself_id_seq'::regclass) NOT NULL,
	error boolean NOT NULL,
	status_code integer NOT NULL,
	headers_id bigint NOT NULL,
	body text NOT NULL,
	enabled boolean DEFAULT true NOT NULL
);

CREATE OR REPLACE FUNCTION grabbing.attach_face(username_ text, face_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	declare _a boolean;
	begin 
    	update grabbing.account as a
    		set face_id = face_id_
    		where a.username = username_
    			and a.face_id is null
    		returning true
    			into _a;
    		
    	return coalesce(_a, false);
	end;
	$$;

CREATE OR REPLACE FUNCTION grabbing.check_existence(username_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	begin 
    	return exists (select 1 from grabbing.account where username = username_);
	end;
	$$;

CREATE OR REPLACE FUNCTION grabbing.create_face(name_ text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	declare _a boolean;
	begin 
    	insert into grabbing.face(id, face_name) select nextval('grabbing.face_id_seq'), name_;
    		
	end;
	$$;

CREATE OR REPLACE FUNCTION grabbing.detach_face(username_ text, face_id_ bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	declare _a boolean;
	begin 
    	update grabbing.account as a
    		set face_id = null
    		where a.username = username_
    			and a.face_id = face_id_
    		returning true
    			into _a;
    		
    	return coalesce(_a, false);
	end;
	$$;

CREATE OR REPLACE FUNCTION grabbing.has_face(username_ text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	begin 
    	return exists (select 1 from grabbing.account a where a.username = username_ and a.face_id is not null);
	end;
	$$;

CREATE OR REPLACE FUNCTION grabbing.receive(quantity_ bigint) RETURNS TABLE(id bigint, url text, parameters_id bigint, headers_id bigint, body text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	begin 
    	return query (
			with cte_sel as (
				select qi.id, qi.url, qi.parameters_id, qi.headers_id, qi.body, qi.host_id
					from grabbing.query_itself qi 
						inner join 
							grabbing.query_host qh 
						on qi.host_id = qh.id 
					where (now() - qh.last_take) >= (qh.sampling_frequency || ' milliseconds')::interval 
						and qi.is_has_response = false 
						and qi.enabled = true 
					order by qi.id
					limit quantity_
			),
			cte_upd as (
				update grabbing.query_host as qh
					set last_take = now()
					where qh.id in (select host_id from cte_sel)
					--returning *
			)--,
			--cte_run_upd as (
			--	select count(1) from cte_upd
			--)
			select qi.id, qi.url, qi.parameters_id, qi.headers_id, qi.body
				from cte_sel qi
					-- cross join
					--	cte_run_upd
					
					);
	end;
	$$;

CREATE OR REPLACE FUNCTION grabbing.receive(quantity_ bigint, face_id_ bigint) RETURNS TABLE(id bigint, url text, parameters_id bigint, headers_id bigint, body text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	begin 
    	return query (
			with cte_sel as (
				select qi.id, qi.url, qi.parameters_id, qi.headers_id, qi.body, qi.host_id
					from grabbing.query_itself qi 
						inner join 
							grabbing.query_host qh 
						on qi.host_id = qh.id 
					where (now() - qh.last_take) >= (qh.sampling_frequency || ' milliseconds')::interval 
						and qi.is_has_response = false 
						and qi.enabled = true 
						and qi.face_id = face_id_
					order by qi.id
					limit quantity_
			),
			cte_upd as (
				update grabbing.query_host as qh
					set last_take = now()
					where qh.id in (select host_id from cte_sel)
					--returning *
			)--,
			--cte_run_upd as (
			--	select count(1) from cte_upd
			--)
			select qi.id, qi.url, qi.parameters_id, qi.headers_id, qi.body
				from cte_sel qi
					-- cross join
					--	cte_run_upd
					
					);
	end;
	$$;

CREATE OR REPLACE FUNCTION grabbing.register(username_ text, password_ text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	begin 
		insert into grabbing.account
			(id, username, password_hashed, face_id, enabled)
			values(nextval('grabbing.account_id_seq'), username_, password_, null, true);
	end;
	$$;

ALTER TABLE grabbing.account
	ADD CONSTRAINT account_pkey PRIMARY KEY (id);

ALTER TABLE grabbing.account
	ADD CONSTRAINT account_username_key UNIQUE (username);

ALTER TABLE grabbing.account_role
	ADD CONSTRAINT account_role_pkey PRIMARY KEY (id);

ALTER TABLE grabbing.face
	ADD CONSTRAINT face_face_name_key UNIQUE (face_name);

ALTER TABLE grabbing.face
	ADD CONSTRAINT face_pkey PRIMARY KEY (id);

ALTER TABLE grabbing.map_item
	ADD CONSTRAINT map_item_pkey PRIMARY KEY (id);

ALTER TABLE grabbing.map_start
	ADD CONSTRAINT map_start_pkey PRIMARY KEY (id);

ALTER TABLE grabbing.query_host
	ADD CONSTRAINT query_host_host_name_key UNIQUE (host_name);

ALTER TABLE grabbing.query_host
	ADD CONSTRAINT query_host_pkey PRIMARY KEY (id);

ALTER TABLE grabbing.query_itself
	ADD CONSTRAINT query_itself_pkey PRIMARY KEY (id);

ALTER TABLE grabbing.relationship_account_and_role
	ADD CONSTRAINT relationship_account_and_role_pkey PRIMARY KEY (id);

ALTER TABLE grabbing.response_itself
	ADD CONSTRAINT response_itself_pkey PRIMARY KEY (id);
