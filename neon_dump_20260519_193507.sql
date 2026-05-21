--
-- PostgreSQL database dump
--

\restrict y0tZIxvkbj2eOwkOjZaSs0Zk5XDkp510OF47Bh6n7vUTgev6d5EOhN09lLcqROr

-- Dumped from database version 16.12 (7bcf9ab)
-- Dumped by pg_dump version 16.14 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: _system; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA _system;


--
-- Name: update_route_stop_names(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_route_stop_names() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE routes 
  SET stop_names = (
    SELECT json_agg(stop_id ORDER BY stop_order) 
    FROM route_stops 
    WHERE route_id = COALESCE(NEW.route_id, OLD.route_id)
  )
  WHERE route_id = COALESCE(NEW.route_id, OLD.route_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: replit_database_migrations_v1; Type: TABLE; Schema: _system; Owner: -
--

CREATE TABLE _system.replit_database_migrations_v1 (
    id bigint NOT NULL,
    build_id text NOT NULL,
    deployment_id text NOT NULL,
    statement_count bigint NOT NULL,
    applied_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: replit_database_migrations_v1_id_seq; Type: SEQUENCE; Schema: _system; Owner: -
--

CREATE SEQUENCE _system.replit_database_migrations_v1_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: replit_database_migrations_v1_id_seq; Type: SEQUENCE OWNED BY; Schema: _system; Owner: -
--

ALTER SEQUENCE _system.replit_database_migrations_v1_id_seq OWNED BY _system.replit_database_migrations_v1.id;


--
-- Name: agency_gtfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agency_gtfs (
    generated_at timestamp without time zone DEFAULT now() NOT NULL,
    agency_id text NOT NULL,
    agency_name text NOT NULL,
    agency_url text,
    agency_timezone text,
    agency_lang text,
    agency_phone text
);


--
-- Name: facilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.facilities (
    facility_id integer NOT NULL,
    old_facility_id text,
    modified_at timestamp without time zone DEFAULT now(),
    facility_name text NOT NULL,
    facility_lat numeric,
    facility_lon numeric,
    lga text,
    lagos_metro text,
    google_maps_url text,
    facility_type text,
    commercial_transport text,
    charter_services text,
    status text,
    quality text,
    image_url text,
    life_jackets text,
    ownership text,
    contact_name text,
    contact_email text,
    laswa_officer_available text,
    source_of_awareness text,
    assignment text,
    additional_notes text,
    facility_name_short text,
    requires_review boolean DEFAULT false,
    category text,
    gcs_url text,
    omi_eko boolean
);


--
-- Name: route_stops; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.route_stops (
    route_stop_id integer NOT NULL,
    route_id integer NOT NULL,
    modified_at timestamp without time zone DEFAULT now(),
    stop_id integer NOT NULL,
    stop_order integer NOT NULL,
    duration_to_stop integer,
    cost_to_stop numeric,
    is_stop_mandatory text
);


--
-- Name: routes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routes (
    route_id integer NOT NULL,
    modified_at timestamp without time zone DEFAULT now(),
    operator text,
    payment_options text,
    boat_types text,
    weekend_equals_weekday_schedule text,
    saturday_equals_sunday_schedule text,
    total_base_duration integer,
    total_base_cost integer,
    hyacinth_season_disruption text,
    rain text,
    geom text,
    route_stops boolean,
    stop_names json,
    additional_notes text,
    contact_name text,
    contact_email text,
    origin integer NOT NULL,
    destination integer NOT NULL,
    requires_review boolean DEFAULT false,
    omi_eko boolean DEFAULT false NOT NULL
);


--
-- Name: bidirectional_route_pairs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.bidirectional_route_pairs AS
 WITH route_stops_ordered AS (
         SELECT route_stops.route_id,
            array_agg(route_stops.stop_id ORDER BY route_stops.stop_order) AS stops_array,
            array_agg(route_stops.stop_id ORDER BY route_stops.stop_order DESC) AS stops_array_reversed
           FROM public.route_stops
          GROUP BY route_stops.route_id
        ), matching_pairs AS (
         SELECT r1.route_id AS route_a_id,
            r2.route_id AS route_b_id,
            rs1.stops_array AS route_a_stops,
            rs2.stops_array AS route_b_stops,
            row_number() OVER (ORDER BY r1.route_id, r2.route_id) AS pair_num
           FROM (((public.routes r1
             JOIN public.routes r2 ON (((r1.origin = r2.destination) AND (r1.destination = r2.origin) AND (r1.route_id < r2.route_id))))
             LEFT JOIN route_stops_ordered rs1 ON ((r1.route_id = rs1.route_id)))
             LEFT JOIN route_stops_ordered rs2 ON ((r2.route_id = rs2.route_id)))
          WHERE (rs1.stops_array = rs2.stops_array_reversed)
        )
 SELECT mp.route_a_id AS route_id,
    ('pair_'::text || (mp.pair_num)::text) AS uid,
    string_agg(f.facility_name, ', '::text ORDER BY stops.ord) AS stop_names_text,
    r1.operator,
    r1.total_base_duration AS duration,
    r1.total_base_cost AS cost,
    r1.weekend_equals_weekday_schedule,
    r1.saturday_equals_sunday_schedule
   FROM (((matching_pairs mp
     JOIN LATERAL unnest(mp.route_a_stops) WITH ORDINALITY stops(stop_id, ord) ON (true))
     JOIN public.facilities f ON ((stops.stop_id = f.facility_id)))
     JOIN public.routes r1 ON ((mp.route_a_id = r1.route_id)))
  GROUP BY mp.pair_num, mp.route_a_id, r1.operator, r1.total_base_duration, r1.total_base_cost, r1.weekend_equals_weekday_schedule, r1.saturday_equals_sunday_schedule
UNION ALL
 SELECT mp.route_b_id AS route_id,
    ('pair_'::text || (mp.pair_num)::text) AS uid,
    string_agg(f.facility_name, ', '::text ORDER BY stops.ord) AS stop_names_text,
    r2.operator,
    r2.total_base_duration AS duration,
    r2.total_base_cost AS cost,
    r2.weekend_equals_weekday_schedule,
    r2.saturday_equals_sunday_schedule
   FROM (((matching_pairs mp
     JOIN LATERAL unnest(mp.route_b_stops) WITH ORDINALITY stops(stop_id, ord) ON (true))
     JOIN public.facilities f ON ((stops.stop_id = f.facility_id)))
     JOIN public.routes r2 ON ((mp.route_b_id = r2.route_id)))
  GROUP BY mp.pair_num, mp.route_b_id, r2.operator, r2.total_base_duration, r2.total_base_cost, r2.weekend_equals_weekday_schedule, r2.saturday_equals_sunday_schedule
  ORDER BY 2, 1;


--
-- Name: calendar_gtfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_gtfs (
    generated_at timestamp without time zone DEFAULT now() NOT NULL,
    service_id text NOT NULL,
    monday boolean NOT NULL,
    tuesday boolean NOT NULL,
    wednesday boolean NOT NULL,
    thursday boolean NOT NULL,
    friday boolean NOT NULL,
    saturday boolean NOT NULL,
    sunday boolean NOT NULL,
    start_date text NOT NULL,
    end_date text NOT NULL
);


--
-- Name: facilities_facility_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.facilities_facility_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facilities_facility_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.facilities_facility_id_seq OWNED BY public.facilities.facility_id;


--
-- Name: facility_destinations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.facility_destinations (
    facility_id integer NOT NULL,
    destination_id integer NOT NULL,
    modified_at timestamp without time zone DEFAULT now(),
    facility_destination_id integer NOT NULL,
    is_charter boolean
);


--
-- Name: facility_destinations_facility_destination_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.facility_destinations_facility_destination_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facility_destinations_facility_destination_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.facility_destinations_facility_destination_id_seq OWNED BY public.facility_destinations.facility_destination_id;


--
-- Name: facility_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.facility_submissions (
    facility_submission_id integer NOT NULL,
    facility_id integer NOT NULL,
    submitted_at timestamp with time zone DEFAULT now(),
    facility_name text NOT NULL,
    facility_type text,
    commercial_transport boolean NOT NULL,
    charter_services boolean NOT NULL,
    life_jackets text NOT NULL,
    contact_name text,
    contact_email text,
    additional_notes text,
    status text DEFAULT 'applied'::text,
    pending_destinations jsonb
);


--
-- Name: facility_submissions_facility_submission_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.facility_submissions_facility_submission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facility_submissions_facility_submission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.facility_submissions_facility_submission_id_seq OWNED BY public.facility_submissions.facility_submission_id;


--
-- Name: feed_info_gtfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_info_gtfs (
    generated_at timestamp without time zone DEFAULT now() NOT NULL,
    feed_publisher_name text NOT NULL,
    feed_publisher_url text,
    feed_lang text NOT NULL,
    feed_start_date text,
    feed_end_date text,
    feed_version text
);


--
-- Name: frequencies_gtfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.frequencies_gtfs (
    generated_at timestamp without time zone DEFAULT now() NOT NULL,
    trip_id text NOT NULL,
    start_time text NOT NULL,
    end_time text NOT NULL,
    headway_secs integer NOT NULL,
    exact_times integer
);


--
-- Name: matching_orig_dest; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.matching_orig_dest AS
 SELECT r.route_id,
    fo.facility_name AS origin_name,
    fd.facility_name AS destination_name,
    COALESCE(string_agg(fs.facility_name, ', '::text ORDER BY rs.stop_order), 'No stops'::text) AS stop_names,
    r.contact_name
   FROM ((((public.routes r
     JOIN public.facilities fo ON ((r.origin = fo.facility_id)))
     JOIN public.facilities fd ON ((r.destination = fd.facility_id)))
     LEFT JOIN public.route_stops rs ON ((r.route_id = rs.route_id)))
     LEFT JOIN public.facilities fs ON ((rs.stop_id = fs.facility_id)))
  WHERE ((r.origin, r.destination) IN ( SELECT routes.origin,
            routes.destination
           FROM public.routes
          GROUP BY routes.origin, routes.destination
         HAVING (count(*) > 1)))
  GROUP BY r.route_id, fo.facility_name, fd.facility_name, r.contact_name
  ORDER BY fo.facility_name, fd.facility_name, r.route_id;


--
-- Name: missing_facility_forms; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.missing_facility_forms AS
 SELECT facility_id,
    facility_name AS facility_name_long,
    status,
    commercial_transport
   FROM public.facilities
  WHERE (NOT (facility_id IN ( SELECT DISTINCT facility_destinations.facility_id
           FROM public.facility_destinations)));


--
-- Name: route_duration_check; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.route_duration_check AS
 SELECT r.route_id,
    COALESCE(sum(COALESCE(rs.duration_to_stop, 0)), (0)::bigint) AS sum_stop_duration,
    COALESCE(max(r.total_base_duration), 0) AS total_duration_submitted,
        CASE
            WHEN (COALESCE(sum(COALESCE(rs.duration_to_stop, 0)), (0)::bigint) = COALESCE(max(r.total_base_duration), 0)) THEN 'accurate'::text
            ELSE 'needs fixing'::text
        END AS verdict
   FROM (public.routes r
     LEFT JOIN public.route_stops rs ON ((rs.route_id = r.route_id)))
  GROUP BY r.route_id
  ORDER BY r.route_id;


--
-- Name: route_periods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.route_periods (
    route_period_id integer NOT NULL,
    route_id integer NOT NULL,
    direction_id integer NOT NULL,
    morning_service boolean,
    evening_service boolean,
    monday boolean,
    tuesday boolean,
    wednesday boolean,
    thursday boolean,
    friday boolean,
    saturday boolean,
    sunday boolean,
    start_time time without time zone,
    end_time time without time zone,
    single_daily_departure boolean,
    average_daily_boat_departures integer,
    frequency character varying(255)
);


--
-- Name: route_periods_route_period_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.route_periods_route_period_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: route_periods_route_period_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.route_periods_route_period_id_seq OWNED BY public.route_periods.route_period_id;


--
-- Name: route_stops_route_stop_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.route_stops_route_stop_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: route_stops_route_stop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.route_stops_route_stop_id_seq OWNED BY public.route_stops.route_stop_id;


--
-- Name: route_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.route_submissions (
    route_submission_id integer NOT NULL,
    route_id integer NOT NULL,
    submitted_at timestamp without time zone DEFAULT now(),
    origin character varying(255) NOT NULL,
    destination character varying(255) NOT NULL,
    operator character varying(255),
    payment_options character varying(1000),
    boat_types character varying(1000),
    weekend_equals_weekday_schedule boolean,
    saturday_equals_sunday_schedule boolean,
    total_base_duration integer,
    total_base_cost numeric,
    hyacinth_season_disruption text,
    rain text,
    route_stops jsonb,
    stop_names text,
    additional_notes text,
    contact_name character varying(255),
    contact_email character varying(255),
    status text DEFAULT 'applied'::text
);


--
-- Name: route_submissions_route_submission_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.route_submissions_route_submission_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: route_submissions_route_submission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.route_submissions_route_submission_id_seq OWNED BY public.route_submissions.route_submission_id;


--
-- Name: routes_gtfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routes_gtfs (
    generated_at timestamp without time zone DEFAULT now() NOT NULL,
    route_id text NOT NULL,
    agency_id text,
    route_short_name text,
    route_long_name text,
    route_type integer
);


--
-- Name: routes_route_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.routes_route_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: routes_route_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.routes_route_id_seq OWNED BY public.routes.route_id;


--
-- Name: routes_with_stop_names; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.routes_with_stop_names AS
 SELECT route_id,
    operator,
    stop_names,
    ( SELECT string_agg(f.facility_name, ' - '::text ORDER BY rs.stop_order) AS string_agg
           FROM (public.route_stops rs
             JOIN public.facilities f ON ((rs.stop_id = f.facility_id)))
          WHERE (rs.route_id = r.route_id)) AS stop_names_text,
    additional_notes
   FROM public.routes r
  ORDER BY route_id;


--
-- Name: shapes_gtfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shapes_gtfs (
    generated_at timestamp without time zone DEFAULT now() NOT NULL,
    shape_id text NOT NULL,
    shape_pt_lat numeric NOT NULL,
    shape_pt_lon numeric NOT NULL,
    shape_pt_sequence integer NOT NULL
);


--
-- Name: stop_times_gtfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stop_times_gtfs (
    generated_at timestamp without time zone DEFAULT now() NOT NULL,
    trip_id text NOT NULL,
    arrival_time text,
    departure_time text,
    stop_sequence integer NOT NULL,
    stop_id text NOT NULL
);


--
-- Name: stops_gtfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stops_gtfs (
    generated_at timestamp without time zone DEFAULT now() NOT NULL,
    stop_id text NOT NULL,
    stop_name text NOT NULL,
    stop_lat numeric NOT NULL,
    stop_lon numeric NOT NULL
);


--
-- Name: time_period_gaps; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.time_period_gaps AS
 WITH periods_with_day_group AS (
         SELECT route_periods.route_period_id,
            route_periods.route_id,
            route_periods.direction_id,
            route_periods.start_time,
            route_periods.end_time,
                CASE
                    WHEN (route_periods.monday AND route_periods.tuesday AND route_periods.wednesday AND route_periods.thursday AND route_periods.friday AND (NOT route_periods.saturday) AND (NOT route_periods.sunday)) THEN 'Weekday'::text
                    WHEN ((NOT route_periods.monday) AND (NOT route_periods.tuesday) AND (NOT route_periods.wednesday) AND (NOT route_periods.thursday) AND (NOT route_periods.friday) AND route_periods.saturday AND route_periods.sunday) THEN 'Weekend'::text
                    WHEN ((NOT route_periods.monday) AND (NOT route_periods.tuesday) AND (NOT route_periods.wednesday) AND (NOT route_periods.thursday) AND (NOT route_periods.friday) AND route_periods.saturday AND (NOT route_periods.sunday)) THEN 'Saturday'::text
                    ELSE 'Other'::text
                END AS day_group
           FROM public.route_periods
        ), ordered_periods AS (
         SELECT periods_with_day_group.route_period_id,
            periods_with_day_group.route_id,
            periods_with_day_group.direction_id,
            periods_with_day_group.day_group,
            periods_with_day_group.start_time,
            periods_with_day_group.end_time,
            lag(periods_with_day_group.end_time) OVER (PARTITION BY periods_with_day_group.route_id, periods_with_day_group.direction_id, periods_with_day_group.day_group ORDER BY periods_with_day_group.start_time) AS prev_end_time
           FROM periods_with_day_group
        )
 SELECT route_period_id,
    route_id,
    direction_id,
    day_group,
    prev_end_time,
    start_time,
    end_time,
        CASE
            WHEN (prev_end_time IS NULL) THEN 'First period'::text
            WHEN (start_time = prev_end_time) THEN 'Continuous'::text
            WHEN ((start_time > prev_end_time) AND ((start_time - prev_end_time) = '00:01:00'::interval)) THEN '1-Minute Gap (data entry)'::text
            WHEN (start_time > prev_end_time) THEN 'Significant Gap (>1 min)'::text
            WHEN (start_time < prev_end_time) THEN 'Overlap (periods conflict)'::text
            ELSE 'Unknown'::text
        END AS status,
    (EXTRACT(epoch FROM (start_time - prev_end_time)) / (60)::numeric) AS gap_minutes
   FROM ordered_periods
  ORDER BY route_id, direction_id, day_group, start_time;


--
-- Name: trips_gtfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trips_gtfs (
    generated_at timestamp without time zone DEFAULT now() NOT NULL,
    trip_id text NOT NULL,
    route_id text NOT NULL,
    service_id text NOT NULL,
    trip_headsign text,
    direction_id integer,
    shape_id text,
    bikes_allowed integer
);


--
-- Name: replit_database_migrations_v1 id; Type: DEFAULT; Schema: _system; Owner: -
--

ALTER TABLE ONLY _system.replit_database_migrations_v1 ALTER COLUMN id SET DEFAULT nextval('_system.replit_database_migrations_v1_id_seq'::regclass);


--
-- Name: facilities facility_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facilities ALTER COLUMN facility_id SET DEFAULT nextval('public.facilities_facility_id_seq'::regclass);


--
-- Name: facility_destinations facility_destination_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_destinations ALTER COLUMN facility_destination_id SET DEFAULT nextval('public.facility_destinations_facility_destination_id_seq'::regclass);


--
-- Name: facility_submissions facility_submission_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_submissions ALTER COLUMN facility_submission_id SET DEFAULT nextval('public.facility_submissions_facility_submission_id_seq'::regclass);


--
-- Name: route_periods route_period_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_periods ALTER COLUMN route_period_id SET DEFAULT nextval('public.route_periods_route_period_id_seq'::regclass);


--
-- Name: route_stops route_stop_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_stops ALTER COLUMN route_stop_id SET DEFAULT nextval('public.route_stops_route_stop_id_seq'::regclass);


--
-- Name: route_submissions route_submission_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_submissions ALTER COLUMN route_submission_id SET DEFAULT nextval('public.route_submissions_route_submission_id_seq'::regclass);


--
-- Name: routes route_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routes ALTER COLUMN route_id SET DEFAULT nextval('public.routes_route_id_seq'::regclass);


--
-- Data for Name: replit_database_migrations_v1; Type: TABLE DATA; Schema: _system; Owner: -
--

COPY _system.replit_database_migrations_v1 (id, build_id, deployment_id, statement_count, applied_at) FROM stdin;
1	4027876d-e6bd-4b69-964e-dde327dc8424	9680f748-b5c8-4096-a0d5-5ad4577a046c	21	2026-02-20 13:56:20.506912+00
2	b38a7537-5d34-49a8-8691-5185854fb75a	9680f748-b5c8-4096-a0d5-5ad4577a046c	2	2026-02-23 15:26:21.775631+00
3	df627864-d605-49f8-9850-c9c0d8d19796	9680f748-b5c8-4096-a0d5-5ad4577a046c	1	2026-03-19 12:15:38.503564+00
\.


--
-- Data for Name: agency_gtfs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.agency_gtfs (generated_at, agency_id, agency_name, agency_url, agency_timezone, agency_lang, agency_phone) FROM stdin;
2026-05-19 14:13:19.872748	LASWA	LagosFerries.com	https://lagosferries.com/	Africa/Lagos	en	
\.


--
-- Data for Name: calendar_gtfs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.calendar_gtfs (generated_at, service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date) FROM stdin;
2026-05-19 14:13:19.872748	SVC_1111100	t	t	t	t	t	f	f	20260421	20270421
2026-05-19 14:13:19.872748	SVC_0000011	f	f	f	f	f	t	t	20260421	20270421
2026-05-19 14:13:19.872748	SVC_1111111	t	t	t	t	t	t	t	20260421	20270421
2026-05-19 14:13:19.872748	SVC_1111110	t	t	t	t	t	t	f	20260421	20270421
2026-05-19 14:13:19.872748	SVC_0000010	f	f	f	f	f	t	f	20260421	20270421
\.


--
-- Data for Name: facilities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.facilities (facility_id, old_facility_id, modified_at, facility_name, facility_lat, facility_lon, lga, lagos_metro, google_maps_url, facility_type, commercial_transport, charter_services, status, quality, image_url, life_jackets, ownership, contact_name, contact_email, laswa_officer_available, source_of_awareness, assignment, additional_notes, facility_name_short, requires_review, category, gcs_url, omi_eko) FROM stdin;
221	\N	2026-03-11 11:59:22.757	Point of No Return	6.405508	2.884629	Badagry	Yes	https://maps.app.goo.gl/3g3KswMeyxLQ1CHk6\n\n	Landing Point	No, it's for charter only	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Fisayo Balogun	fisayo@publictech.studio	No	Tour Guide	\N	\N	Point of No Return	f	Charter only	https://storage.googleapis.com/ferry-facilities/point_of_no_return.jpg	f
109	74	2026-02-10 12:58:18.428	Oke Ira Nla (Ajah)	6.4906336	3.5790217	Eti Osa	Yes	https://maps.app.goo.gl/NrGi7SyXoXE1h1Ap7	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/74_oke_ira_nla__ajah_jetty_.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Mr Ismail	ismailolalekan68@yahoo.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Oke Ira Nla	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/oke_ira_nla_ajah.jpg	t
62	96	2026-02-20 11:47:04.648	Ibeshe Palace	6.411298075	3.255760155	Amuwo Odofin	Yes	https://maps.app.goo.gl/pcYFQajs6i8kASer6	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/96_ibeshe_palace.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	ibese palace is an intermediate stop	Ibeshe Palace	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ibeshe_palace.jpg	f
90	114	2026-03-05 02:49:21.182	Jemuje	6.417815267	3.350526717	Amuwo Odofin	Yes	https://maps.app.goo.gl/PxYnadUbtDYp4Sdc6	Landing Point	No, it's for charter only	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/114_jemuje.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo	This facility is for charter only.	Jemuje	f	Charter only	https://storage.googleapis.com/ferry-facilities/jemuje.jpg	f
74	108	2026-03-04 20:23:14.343	Ikare town landing	6.417336462	3.236747347	Amuwo Odofin	Yes	https://maps.app.goo.gl/SSQ1XkMnA3ZCH86t9	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/108_ikare_town_landing.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	\N	Ikare town landing	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/ikare_town_landing.jpg	f
115	\N	2026-01-13 00:00:00	Oreta Water	6.530598	3.521682	Ikorodu	Yes	https://maps.app.goo.gl/q3jKmWXMWBK87Fxc7	Jetty	\N	\N	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Location unknown	\N	Oreta Water	f	Not included: Location unknown	\N	f
136	29	2026-01-13 00:00:00	VIP Charlet Waterfront Badagry	6.4095965	2.9006206	Badagry	No	https://maps.app.goo.gl/VWWQUy7SyZSt3i829	Ferry Terminal	Yes, anyone from the public can buy a ticket here	\N	not_in_use	Developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - Outside metro	\N	VIP Charlet Waterfront Badagry	f	Not included: Outside metro	\N	f
30	135	2026-02-27 10:43:37.24	Baba Shino	6.424669926	3.257495156	Amuwo Odofin	Yes	https://maps.app.goo.gl/GWnTr9KF1vZjhXQG8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/135_baba_shino.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo	\N	Baba Shino	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/baba_shino.jpg	f
156	\N	2026-03-03 09:06:23.674	Farasime	6.4308333868929	2.7098418861795324	Badagry	Yes	https://maps.app.goo.gl/bMer2JV3zgCuyc8r8	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	\N	Every person is wearing a life jacket	\N	Officer Samuel 	Samuelolorunwamautin@yahoo.com	No	LASWA officer	\N	Charter is available to those destinations. This isn’t the origin jetty	Farasimeh	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/farasime.jpg	f
222	\N	2026-03-25 10:12:02.552	Imore Community	6.426853	3.280746	Amuwo Odofin	Yes	https://maps.app.goo.gl/4LuMmTCHPdBxV5yDA	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	No one is wearing a life jacket	\N	Fisayo Balogun	fisayo@publictech.studio	No	Fisayo	\N	\N	Imore Community	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/imore_community.jpg	f
51	59	2026-02-13 09:38:14.402	Etegbin	6.44938129866523	3.1438987931594227	Ojo	Yes	https://maps.app.goo.gl/DrKxHcT7J6jtv6zX8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/59_etegbin_jetty.jpg	Every person is wearing a life jacket	Unknown - Terminals/Jetties without LASWA Oversight	Mr olowoseelu festus	Remiolusoji7@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	Charter is only to those 2 locations 	Etegbin	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/etegbin.jpg	f
65	54	2026-01-13 00:00:00	Igbogbele Badagry	6.4432466	2.7798856	Badagry	No	https://maps.app.goo.gl/EHKTspTfmmK34A2t9	Jetty	\N	\N	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	No visible sign of boats/jetty from satellite imagery. 	Igbogbele Badagry	f	Not included: Outside metro	\N	f
114	85	2026-02-20 21:24:21.544	Olu landing	6.407796141	3.259976411	Amuwo Odofin	Yes	https://maps.app.goo.gl/yiWEWUmYB4KHR1a38	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	it is an intermediate stop.	Olu landing	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/olu_landing.jpg	f
6	17	2026-02-27 12:14:22.419	Marina/CMS	6.4492081354225945	3.389713112398539	Lagos Island	Yes	https://maps.app.goo.gl/oBtY5TcnSDEvAJp37	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/17_marina_cms.jpg	Every person is wearing a life jacket	NIWA	Charity Sikigha	isikighacharity@gmail.com	Yes	LASWA website	Charity Sikigha, Israel Ekundayo	\N	Marina/CMS	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/marina_cms.jpg	t
130	44	2026-02-18 12:09:42.939	Tarkwa Bay	6.4010654	3.3965995	Eti Osa	Yes	https://maps.app.goo.gl/C86HkQBxKBDYjVDZ7	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/44_tarkwa_bay_jetty.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Sikigha Charity	isikighacharity@gmail.com	No	LASWA website	Charity Sikigha	Majority of the boats at tarkwa bay are privately chartered even though they are commercial boats because of the business type at tarkwa bay. The frequency of boats movements can only be determined by passengers availablity which can't even be guessed again due to the business type at tarkwa bay.	Tarkwa Bay	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/tarkwa_bay.jpg	f
78	115	2026-03-05 03:06:10.67	Ilutuntun	6.422202391	3.349318874	Amuwo Odofin	Yes	https://maps.app.goo.gl/Ah2bMZz9Fpgpm1B37	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/115_ilutuntun.jpg	Only some people are wearing life jackets (not everyone)	Unknown - Not on LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo	This is not a destination facility. It is an intermediate stop for the route: Liverpool (Apapa) to Isoda	Ilutuntun	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ilutuntun.jpg	f
20	79	2026-03-11 09:22:05.802	Agboyi 3	6.5824155	3.4081684	Kosofe	Yes	https://maps.app.goo.gl/7TWqE1z2QLVoyeL48	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/79_agboyi_1_stop.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Fisayo Balogun	fisayo@publictech.studio	No	Public Tech Studio	Done by Fisayo - LASWA assigned facilities	\N	Agboyi 3	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/agboyi_3.jpg	f
67	11	2026-02-19 10:42:14.221	Igbologun/Snake Island	6.427478038731522	3.3345191161320713	Amuwo Odofin	Yes	https://maps.app.goo.gl/13G3LLBcGGpU7CXKA	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/11_igbologun_jetty.jpg	Only some people are wearing life jackets (not everyone)	Unknown - Terminals/Jetties without LASWA Oversight	Israel Ekundayo	israelekundayo@gmail.com	No	LASWA website	Israel Ekundayo	It should be just Igbologun, not Igbologun (ojo).\nAlso, from Igbologun, the drivers and workers there claim that one can privately charter a boat ride to anywhere that's a "water side" (Liverpool, CMS, Badagry, Ijegun, Igbo Elejo, etc.).	Igbologun/Snake Island	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/igbologun_snake_island.jpg	t
200	\N	2026-03-06 11:39:31.302	Badore Ferry Terminal	6.5121945	3.6152349	Eti Osa	Yes	https://maps.app.goo.gl/bDhoL4FzjHaBv543	Ferry Terminal	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/34_badore_terminal.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Fisayo Balogun	fisayo@publictech.studio	Yes	Fisayo	DO NOT ASSIGN - Get from LASWA officer	\N	Badore Terminal	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/badore_ferry_terminal.jpg	t
77	40	2026-02-26 11:19:07.836	Ilashe	6.40667	3.2055711	Amuwo Odofin	Yes	https://maps.app.goo.gl/oGxRCRF3LqS4RSSMA	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/40_ilashe.jpg	Every person is wearing a life jacket	Unknown - Terminals/Jetties without LASWA Oversight	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	LASWA website	Victor Kokodoko	it is an intermediate stop	Ilashe	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/ilashe.jpg	f
106	36	2026-02-20 11:01:57.43	Ogogoro Village	6.426261846113661	3.3983397610213615	Apapa	Yes	https://maps.app.goo.gl/7XQRVKoHBtE4YEpx5	Landing Point	No, it's for charter only	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/36_ogogoro_village.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Sikigha Charity	isikighacharity@gmail.com	No	Public Tech Studio	Charity Sikigha	Its a landing for the people who live on or around that island. Usually people join boats headed to tarkwa bay and make a stop there. There are no designated boats for that particular location usually.	Ogogoro Village	f	Charter only	https://storage.googleapis.com/ferry-facilities/ogogoro_village.jpg	f
38	70	2026-02-09 11:58:46.683	Coconut Landing	6.4379208	3.3358558	Apapa	Yes	https://maps.app.goo.gl/sjRn4QH1HYcvmFu18	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/70_coconut_landing.jpg	Every person is wearing a life jacket	Unclear - Landing Public Access	Mr Joseph 	None	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Coconut	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/coconut_landing.jpg	t
56	41	2026-01-13 00:00:00	Ganyingbo Topa Waterways	6.423654	2.8522655	Badagry	No	https://maps.app.goo.gl/LZdjFk2a4SJ8V3FA8	Unknown	\N	\N	not_in_use	Unknown	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - Outside metro	\N	Ganyingbo Topa Waterways	f	Not included: Outside metro	\N	f
35	129	2026-03-02 10:27:43.737	Boundary (Apapa)/Number 3 (Apapa) Waterside	6.450410928	3.351580945	Apapa	Yes	https://maps.app.goo.gl/KXB6PS6ZGsBuZ45Z7	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/129_boundary__apapa_.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	\N	Boundary/Number 3 (Apapa)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/boundary_apapa_number_3_apapa_waterside.jpg	f
54	134	2026-03-24 12:12:16.963	Fiki Marine (Victoria Island)	6.43922746	3.424595555	Eti Osa	Yes	https://maps.app.goo.gl/Bk1o11Ditz6awsAB9	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/134_fiki_marine.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Hannah Kates	hannah@publictech.studio	No	Public Tech Studio	Hannah	All tickets are round-trip.	Fiki Marine	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/fiki_marine_victoria_island.jpg	f
91	39	2026-03-02 10:33:37.282	KabaKaba	6.4311226	3.3733927	Apapa	Yes	https://maps.app.goo.gl/tsrNJ1fDCKTDr6em8	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Done by Fisayo - LASWA assigned facilities	\N	KabaKaba	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/kabakaba.jpg	f
92	136	2026-02-25 18:44:57.294	Kirikiri	6.437342371	3.310792342	Amuwo Odofin	Yes	https://maps.app.goo.gl/8SjfajtUKCBcxja37	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/136_kirikiri.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Charity Sikigha	isikighacharity@gmail.com	No	Public Tech Studio	Charity Sikigha	\N	Kirikiri	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/kirikiri.jpg	f
57	\N	2026-03-03 09:06:04.755	Gbaji Yekeme Jetty	6.419563687	2.86074950	Badagry	No	https://maps.app.goo.gl/bi8y4DGzmLHQqddDA	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Officer Samuel 	Samuelolorunwamautin@yahoo.com	Yes	LASWA list from Lanre/Ibrahim	DO NOT ASSIGN - Get from LASWA officer	Charter is available to those destinations. This isn’t the origin jetty	Gbaji Yekeme	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/gbaji_yekeme_jetty.jpg	f
95	\N	2026-01-13 00:00:00	Langbasa	6.509071	3.579538	Eti-Osa	Yes	https://maps.app.goo.gl/X2UMN5t48WDBRsYK8	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	not_in_use	Less developed	\N	\N	LASWA/State according to LASWA website	\N	\N	No	LASWA website	DO NOT ASSIGN - Location unknown	\N	Langbasa	f	Not included: Location unknown	\N	f
144	\N	2026-03-11 09:50:50.647	Ijon Odo (Ogun)	6.561944	3.195462	Outside Lagos: Ogun State	No	https://maps.app.goo.gl/TxAPiqgDEWgakJY5A	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	\N	Only some people are wearing life jackets (not everyone)	Ogun State	Fisayo Balogun	fisayo@publictech.studio	No	LASWA officer	\N	Charter is possible to the destination	Ijon Odo (Ogun)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/ijon_odo_ogun.jpg	f
63	\N	2026-02-11 10:29:59.941	Igando Landing/Isuti	6.552229	3.206473	Alimosho	Yes	https://maps.app.goo.gl/BkifHvPvDvxEsXtHA	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Mr Komolafe Michael Temitope	komolafetemitope5555@gmail.com	Yes	LASWA list from Lanre/Ibrahim	DO NOT ASSIGN - Get from LASWA officer	Charter services is only to Totowu	Igando Landing/Isuti	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/igando_landing_isuti.jpg	f
2	18	2026-03-11 09:22:11.475	Five Cowries/Falomo (Ikoyi)	6.442095174	3.427179994	Eti Osa	Yes	https://maps.app.goo.gl/RQPmE1RQEQBhnCCf7	Ferry Terminal	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/18_five_cowries_falomo_ise_water.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Fisayo Balogun	fisayo@publictech.studio	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Five Cowries/Falomo	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/five_cowries_falomo_ikoyi.jpg	t
107	86	2026-02-27 09:23:22.335	Ojo market waterside	6.453176022	3.204245481	Ojo	Yes	https://maps.app.goo.gl/dMpjXQoTvKLLC6vK6	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/86_ojo_market.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo, Victor Kokodoko	\N	Ojo market waterside	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/ojo_market_waterside.jpg	f
44	94	2026-02-20 11:27:03.419	Elegushi	6.411355033	3.254269161	Amuwo Odofin	Yes	https://maps.app.goo.gl/jq8R2TkSBPPgyrM8A	Jetty	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/94_elegushi.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	it is an intermediate stop, the origin is ijegun egba	Elegushi	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/elegushi.jpg	f
55	128	2026-03-02 10:48:08.523	First Gate (Tin Can Island)	6.435334458	3.343388481	Apapa	Yes	https://maps.app.goo.gl/smM1emMG1cTpPouf6	Jetty	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/128_first_gate__tin_can_island_.jpg	Only some people are wearing life jackets (not everyone)	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	\N	First Gate (Tin Can Island)	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/first_gate_tin_can_island.jpg	t
40	25	2026-01-13 00:00:00	Ebute Lekki	6.403051	4.134563	Ibeju Lekki	No	https://maps.app.goo.gl/E5tDgp6gNRYJNxLbA	Ferry Terminal	Yes, anyone from the public can buy a ticket here	\N	not_in_use	Developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - Outside metro	\N	Ebute Lekki	f	Not included: Outside metro	\N	f
86	\N	2026-02-25 09:24:35.367	Itomu Jetty	6.500702360667333	3.6287304042043047	Epe	No	https://maps.app.goo.gl/tJQhEfJWo9emgdUGA	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Mr Haruna Deji	harunadeji05@gmail.com	Yes	LASWA list from Lanre/Ibrahim	DO NOT ASSIGN - Get from LASWA officer	Charter is only available to the destinations	Itomu Jetty	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/itomu_jetty.jpg	f
146	\N	2026-03-11 09:50:42.375	Owode	\N	\N	Badagry	No	\N	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Fisayo Balogun	fisayo@publictech.studio	No	LASWA officer	\N	Can't find this. Could be Owode Apa but it’s all surrounded by land too\n	Owode	f	Ferry facility: Less developed	\N	f
21	67	2026-03-11 09:22:01.43	Agboyi 2	6.5802865	3.4084039	Kosofe	Yes	https://maps.app.goo.gl/oRxFS5LWKDXbLVz68	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/67_agboyi_2_stop.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Fisayo Balogun	fisayo@publictech.studio	No	Public Tech Studio	Done by Fisayo - LASWA assigned facilities	\N	Agboyi 2	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/agboyi_2.jpg	f
125	84	2026-02-27 10:42:49.374	Second Rainbow Landing	6.425671629	3.262277583	Amuwo Odofin	Yes	https://maps.app.goo.gl/XAe6pLRZLLWTWfnG8	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/84_second_rainbow_landing.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo	\N	Second Rainbow	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/second_rainbow_landing.jpg	f
98	5	2026-01-13 00:00:00	Mainland Iddo	6.4705735	3.3845329	Lagos Mainland	Yes	https://maps.app.goo.gl/fz7pQFtFQc1FD4mr8	Landing Point	No commercial passenger activity	No, it is not possible	not_in_use	Less developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - No passenger activity	\N	Mainland Iddo	f	Not included: No commercial passenger activity	\N	f
157	\N	2026-03-11 09:50:44.25	Izigi (Ogun)	6.472321493181269	2.862023411768888	Outside Lagos: Ogun State	No	https://maps.app.goo.gl/fVXGFF8FYBSS2rs79	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Fisayo Balogun	fisayo@publictech.studio	No	LASWA officer	\N	\N	Izigi (Ogun)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/izigi_ogun.jpg	f
145	\N	2026-03-11 09:50:34.323	Oto Owu Odo (Ogun)	6.552369	3.198343	Outside Lagos: Ogun State	No	https://maps.app.goo.gl/bmHnyFcLKBimnAUP7	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	\N	Only some people are wearing life jackets (not everyone)	Ogun State	Fisayo Balogun	fisayo@publictech.studio	No	LASWA officer	\N	Charter is available only to the destination	Totowu Odo (Ogun)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/oto_owu_odo_ogun.jpg	f
80	137	2026-02-24 09:37:00.461	Irede	6.428563414	3.235353134	Amuwo Odofin	Yes	https://maps.app.goo.gl/7b7p2W4A5AGq4er97	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/137_irede_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	Yes	Public Tech Studio	Victor Kokodoko	\N	Irede	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/irede.jpg	f
70	65	2026-02-09 13:40:49.351	Ijegun Egba	6.427831	3.258691	Amuwo Odofin	Yes	https://maps.app.goo.gl/yxmFu7GYTrtXRbiH6	Ferry Terminal	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/65_ijegun_egba.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Mr Damilola Hassan	damexsy@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	You can also get to Ilashe beach from here by entering Ibeshe boat but paying an extra extra fee.	Ijegun Egba	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ijegun_egba.jpg	t
123	122	2026-01-13 00:00:00	Seaport	\N	\N	\N	\N	https://maps.app.goo.gl/8hhLAkBaoEaCUskC9	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	not_in_use	Less developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - Location unknown	Seaport is a generic name and appears in multiple places	Seaport	f	Not included: Location unknown	\N	f
68	\N	2026-01-13 00:00:00	Igbonla	\N	\N	Badagry	No	\N	Unknown	\N	\N	not_in_use	Unknown	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	All surrounded by land\n	Igbonla	f	Not included: Outside metro	\N	f
39	\N	2026-01-13 00:00:00	Dadilum In Olorunda Lcda	\N	\N	Badagry	No	\N	Unknown	\N	\N	not_in_use	Unknown	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	Olorunda is located in Osogbo	Dadilum In Olorunda Lcda	f	Not included: Outside metro	\N	f
1	16	2026-03-11 08:56:51.245	Ebute Ero/Elegbata Jetty	6.462741	3.3824812	Lagos Island	Yes	https://maps.app.goo.gl/2Rcwh9xQ19TxAgFo6	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/16_ebute_ero.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Fisayo Balogun	fisayo@publictech.studio	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	Charter is possible to destinations	Ebute Ero	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ebute_ero_elegbata_jetty.jpg	t
75	123	2026-03-02 10:50:05.963	IKO/Temidire	6.436872961	3.344148423	Ajeromi/Ifelodun	Yes	https://maps.app.goo.gl/B8kUNoXnQyWhSYWw5	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/123_iko_temidire_jetty.jpg	Only some people are wearing life jackets (not everyone)	Not LASWA/State according to LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	Next to the jetty are fibres boats you can charter to Ibasa for 20000-30000 naira depending on your luggage.You can't charter boats to First Gate(TinCan Island)	IKO/Temidire	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/iko_temidire.jpg	f
14	12	2026-02-10 09:30:34.112	Offin, Ikorodu	6.5393273	3.5010197	Ikorodu	Yes	https://maps.app.goo.gl/3cpEL28rNN9gsb5S8	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/12_offin_jetty__ikorodu.jpg	Every person is wearing a life jacket	Unknown - Terminals/Jetties without LASWA Oversight	Mr Olabinjo Lateef	olabinjolafet@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Offin	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/offin_ikorodu.jpg	f
153	\N	2026-03-11 09:50:48.665	Ipare (Ondo)	6.2907986756471	4.674969608516989	Outside Lagos: Ondo State	No	https://maps.app.goo.gl/Y3WT4fZ9BWVWVLkdA	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Fisayo Balogun	fisayo@publictech.studio	No	LASWA officer	\N	\N	Ondo (Ipare)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/ipare_ondo.jpg	f
100	110	2026-03-11 13:10:38.154	Mikano	6.407742225	3.216321522	Amuwo Odofin	Yes	https://maps.app.goo.gl/K7iKJGvDXjqGAJxU6	Jetty	No, it's for charter only	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/110_mikano.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Fisayo Balogun	fisayo@publictech.studio	No	Public Tech Studio	Victor Kokodoko	\N	Mikano	f	Charter only	https://storage.googleapis.com/ferry-facilities/mikano.jpg	f
31	19	2026-02-10 13:56:47.8	Baiyeku	6.536139	3.553069	Ikorodu	Yes	https://maps.app.goo.gl/ASdVgc1UYJnj92HR7	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/19_baiyeku_jetty.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Mr Bassey Iniobong	iniobong04@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	Charter is limited to ijede and oke Ira jetties	Baiyeku	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/baiyeku.jpg	t
58	82	2026-02-25 17:58:58.617	Gberigbe	6.571305167	3.636099754	Ikorodu	Yes	https://maps.app.goo.gl/Etp9x8RgpooLppbd7	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/82_gberigbe_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Charity Sikigha	isikighacharity@gmail.com	No	Public Tech Studio	Charity Sikigha	\N	Gberigbe	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/gberigbe.jpg	f
5	10	2026-03-02 10:38:10.38	Flour Mills (Apapa)	6.4477052	3.3749219	Apapa	Yes	https://maps.app.goo.gl/CUgKrY5nLbSeYfoP8	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/10_apapa_flour_mill_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun, Charity Sikigha	You can charter fibre boats here owned by private individuals.	Flour Mill	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/flour_mills_apapa.jpg	t
60	90	2026-02-20 10:13:29.119	Ibese	6.407574489	3.261663392	Amuwo Odofin	Yes	https://maps.app.goo.gl/L4pqTGttjygG8dSe8	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/90_ibese.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	It is an intermediate stop	Ibese	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ibese.jpg	f
93	93	2026-02-20 21:50:34.616	Koko beach	6.409081268	3.24343704	Amuwo Odofin	Yes	https://maps.app.goo.gl/qQkX6iaS9jMGsQW57	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/93_koko_beach.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	it is an intermediate stop	Koko beach	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/koko_beach.jpg	f
141	106	2026-02-13 09:36:50.425	Isofin	6.449265067922099	3.1451277430765003	Ojo	Yes	https://maps.app.goo.gl/u2bAU2HDTwTqg1929	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	\N	Every person is wearing a life jacket	\N	Mr Olowoseelu Festus	Remiolusoji7@gmail.com	No	Public Tech Studio	\N	Charter is only to Etegbin. This was previously recorded as Ese Ofin, correct name was given by locals	Isofin	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/isofin.jpg	f
69	30	2026-02-10 12:16:41.639	Ijede/Tarzan	6.5632172	3.5890471	Ikorodu	Yes	https://maps.app.goo.gl/HVJFD62oxKqrFZg39	Jetty	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Developed	\N	Every person is wearing a life jacket	LASWA/State according to LASWA website	Mr Michael Diyepiriwei	diyemichael@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Ijede/Tarzan	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ijede_tarzan.jpg	t
15	13	2026-02-10 09:02:13.842	Ibeshe/Thesaurus Ferry Terminal	6.5523891	3.4728735	Ikorodu	Yes	https://maps.app.goo.gl/tiSt4NbDpn54x4hi8	Ferry Terminal	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/13_ibeshe_ferry_terminal_thesaurus_ferry_terminal.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	ISHOLA TAIWO OLANREWAJU 	isholataiwoolanrewajutiems@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Ibeshe Ikorodu	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ibeshe_thesaurus_ferry_terminal.jpg	f
8	34	2026-02-25 09:23:47.677	Badore Jetty (Tarzan)	6.5151518	3.6054649	Eti Osa	Yes	https://maps.app.goo.gl/GKdC2UawQ5Ef2BpJ9	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/62_tarzan_jetty.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Mr Michael Diyepiriwei	diyemichael@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	Charter is only available to the destinations	Badore Jetty 	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/badore_jetty_tarzan.jpg	t
37	91	2026-02-25 18:50:46.22	Cele	6.427885821	3.25580105	Amuwo Odofin	Yes	https://maps.app.goo.gl/APeKThH4CHLjupPeA	Landing Point	No, it's for charter only	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/91_cele.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo	This facility is NOT a route origin. It is mainly used as a charter for moving heavy loads.	Cele	f	Not included: No commercial passenger activity	https://storage.googleapis.com/ferry-facilities/cele.jpg	f
102	130	2026-03-02 10:31:41.459	Mogaji (Ajegunle)	6.446059237	3.349851834	Ajeromi/Ifelodun	Yes	https://maps.app.goo.gl/5Bbh86aEnDmpdLtAA	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/130_mogaji__ajegunle_.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	\N	Mogaji (Ajegunle)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/mogaji_ajegunle.jpg	f
89	87	2026-03-04 20:28:39.861	Iyagbe	6.419640776	3.19931338	Amuwo Odofin	Yes	https://maps.app.goo.gl/DXFzoLyXgefDgodR9	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/87_iyagbe_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	\N	Iyagbe	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/iyagbe.jpg	f
155	\N	2026-03-11 09:50:55.018	Eyin Osa	6.567449855315829	3.9753541928079983	Epe	No	https://maps.app.goo.gl/EBTvAAKcyrcHebzy9	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Fisayo Balogun	fisayo@publictech.studio	No	LASWA officer	\N	Charter is possible to the destination	Eyin Osa	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/eyin_osa.jpg	f
154	\N	2026-03-11 09:50:46.426	Iwopin (Ogun)	6.5182992422275134	4.192336731520612	Outside Lagos: Ogun State	No	https://maps.app.goo.gl/gKuf5PNSgjonCm1L7	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Fisayo Balogun	fisayo@publictech.studio	No	LASWA officer	\N	\N	Ogun (Iwopin)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/iwopin_ogun.jpg	f
64	132	2026-03-05 03:08:43.173	Igbo Elejo	6.42421763	3.352115435	Amuwo Odofin	Yes	https://maps.app.goo.gl/54ZP2uqC2gCe1ny87	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/132_igbo-elejo.jpg	Only some people are wearing life jackets (not everyone)	Unknown - Not on LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo	This facility is an intermediate stop for the route Liverpool (Apapa) to Isoda	Igbo Elejo	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/igbo_elejo.jpg	f
73	107	2026-02-18 21:45:24.876	Ikare palace	6.417633427	3.238141222	Amuwo Odofin	Yes	https://maps.app.goo.gl/MVg9ngjJfcTD2UVu6	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/107_ikare_palace_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	Ikare Palace is a jetty,about 200m from the landing	Ikare palace	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ikare_palace.jpg	f
45	55	2026-01-13 00:00:00	Emina-Saga Epe	6.5463207	4.0828507	Epe	No	https://maps.app.goo.gl/ifRZd7sA2hddX7em7	Jetty	\N	\N	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	\N	Emina-Saga Epe	f	Not included: Outside metro	\N	f
87	58	2026-01-13 00:00:00	Iworo Ajido	6.4137857	3.0078911	Badagry	No	https://maps.app.goo.gl/JzKSorTZwpdsohCb8	Unknown	\N	\N	not_in_use	Unknown	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	\N	Iworo Ajido	f	Not included: Outside metro	\N	f
10	15	2026-02-09 10:10:58.615	Liverpool (Apapa)	6.4390793	3.3592365	Apapa	Yes	https://maps.app.goo.gl/4jazuQu4yYnqhnMo9	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/15_liverpool__apapa_.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Liverpool	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/liverpool_apapa.jpg	t
7	76	2026-03-03 17:48:14.595	Addax/Sandfill/Maroko (Victoria Island)	6.436702621424786	3.4419826471853696	Eti Osa	Yes	https://maps.app.goo.gl/rVE9vKquB1FtT2Ao6	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/76_addax_sandfill_maroko_jetty.jpg	Every person is wearing a life jacket	Not LASWA/State according to LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	LASWA website	Charity Sikigha, Israel Ekundayo	\N	Addax/Sandfill	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/addax_sandfill_maroko_victoria_island.jpg	t
22	66	2026-03-11 09:21:37.888	Oko Agbon	6.5798309	3.4108125	Kosofe	Yes	https://maps.app.goo.gl/LRQdm1zhz3YwZa7X8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/66_agboyi_3_oko_agbon.jpg	Only some people are wearing life jackets (not everyone)	Unknown - Not on LASWA website	Fisayo Balogun	fisayo@publictech.studio	No	Public Tech Studio	Done by Fisayo - LASWA assigned facilities	\N	Oko Agbon	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/oko_agbon.jpg	f
19	101	2026-03-06 21:09:42.817	Agaja	6.403919063	3.164768668	Ojo	Yes	https://maps.app.goo.gl/udbPEqvt2TH1Uxpd6	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/101_agaja_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo	None	Agaja	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/agaja.jpg	f
220	\N	2026-03-09 13:32:35.604	Alelegbene	6.426392	3.355594	Apapa	Yes	https://maps.app.goo.gl/b3B1nUDrH69sUFDA9	Landing Point	No, it's for charter only	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Contractor - Ayodeji Adesegun	\N	Most chartered destination: Liverpool.	Alelegbene	f	Charter only	https://storage.googleapis.com/ferry-facilities/alelegbene.jpg	f
118	7	2026-01-13 00:00:00	Oworonsoki	6.5482938	3.4068744	Kosofe	Yes	https://maps.app.goo.gl/KwYJxkK7yFPyzS3b8	Jetty	No commercial passenger activity	No, it is not possible	not_in_use	Developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - No passenger activity	\N	Oworonsoki	f	Future Omi Eko	\N	t
119	95	2026-02-20 21:32:29.844	Police	6.411970909	3.252469639	Amuwo Odofin	Yes	https://maps.app.goo.gl/eFcoA8pUAeLBoJWh7	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/95_police.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	it is an intermediate stop	Police	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/police.jpg	f
83	\N	2026-02-13 10:31:09.213	Isashi Landing	6.510683	3.173494	Ojo	Yes	https://maps.app.goo.gl/x5toTtnMRgU6s86z8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Mr Amodu Falilu	Amoduoluwafemi64@yahoo.com	Yes	LASWA list from Lanre/Ibrahim	DO NOT ASSIGN - Get from LASWA officer	Charter is only possible to Destination 	Isashi Landing	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/isashi_landing.jpg	f
133	45	2026-03-05 15:24:54.568	Tolu Ajegunle	6.4396574	3.3547922	Apapa	Yes	https://maps.app.goo.gl/j1J4QPWMDuKuXdDS8	Jetty	No, it's for private use only	No, it is not possible	not_in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/45_tolu_ajegunle.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	It belongs to an Anglican church. The church uses the jetty for its own purposes.	Tolu Ajegunle	f	Not included: Private only	https://storage.googleapis.com/ferry-facilities/tolu_ajegunle.jpg	f
9	64	2026-02-11 12:55:50.978	Ebute Ojo/Sifax Ferry Terminal	6.453045	3.2055781	Ojo	Yes	https://maps.app.goo.gl/f3p9vrz7V6oaFDzHA	Ferry Terminal	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/64_ebute_ojo_sifax_ferry_terminal.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Mr Pascal	N/a	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Ebute Ojo/Sifax	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ebute_ojo_sifax_ferry_terminal.jpg	t
23	22	2026-02-12 08:03:10.822	Agboyi Ketu	6.5825306	3.4075406	Kosofe	Yes	https://maps.app.goo.gl/JJgFfFNMDPkXc7c56	Jetty	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/22_agboyi_ketu.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Otudero Taiwo Oluwayemisi	None	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Agboyi Ketu	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/agboyi_ketu.jpg	f
142	\N	2026-02-13 10:30:25.17	Itekun (Ogun)	6.514275458385697	3.170501289484946	Outside Lagos: Ogun State	No	https://maps.app.goo.gl/4oWT3STmpYAg4ndR8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Mr Amodu Falilu	Amoduoluwafemi64@yahoo.com	No	LASWA officer	\N	Charter is only possible to destination 	Iteku	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/itekun_ogun.jpg	f
66	\N	2026-01-13 00:00:00	Igbologun (Ibeju Lekki)	\N	\N	Ibeju Lekki	No	\N	Unknown	\N	\N	not_in_use	Unknown	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	There’s no Igbologun on the island. There is “Igbolodun” but all land 	Igbologun (Ibeju Lekki)	f	Not included: Outside metro	\N	f
101	14	2026-02-25 16:58:08.149	Mile 2/NIWA	6.4590664	3.3077366	Amuwo Odofin	Yes	https://maps.app.goo.gl/d4PvzRNLJZRJrSAU7	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/14_mile_2___niwa_jetty.jpg	Every person is wearing a life jacket	NIWA	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo	None	Mile 2	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/mile_2_niwa.jpg	t
33	35	2026-01-13 00:00:00	Boat Club (Ikoyi)	6.4429111	3.409454	Eti Osa	Yes	https://maps.app.goo.gl/YKRSGuW3eLbMTtND9	Jetty	No, it's for private use only	No, it is not possible	not_in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/35_boat_club.jpg	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - Private facility that passengers can't use	\N	Boat Club	f	Not included: Private only	https://storage.googleapis.com/ferry-facilities/boat_club.jpg	f
25	\N	2026-01-13 00:00:00	Agura Landing	\N	\N	Ikorodu	Yes	\N	Unknown	\N	\N	not_in_use	Unknown	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Location unknown	No water body close to location. Not included: Location unknown	Agura Landing	f	Not included: Location unknown	\N	f
126	43	2026-03-11 11:58:41.425	Slave Route Landing	6.4113884	2.8836426	Badagry	No	https://maps.app.goo.gl/VJetkHmt7mQZa3a36	Landing Point	No, it's for charter only	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	Unclear - Landing Public Access	Fisayo Balogun	fisayo@publictech.studio	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Slave Route	f	Charter only	https://storage.googleapis.com/ferry-facilities/slave_route_landing.jpg	f
137	26	2026-01-13 00:00:00	White Sand Oyingbo	6.4769088	3.3883303	Lagos Mainland	Yes	https://maps.app.goo.gl/eZ6uQu4qUBxPDKeBA	Unknown	\N	\N	not_in_use	Unknown	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - No passenger activity	\N	White Sand Oyingbo	f	Not included: No commercial passenger activity	\N	f
152	\N	2026-02-25 09:57:53.556	Kabiyesi itomu jetty	6.502234	3.626850	Epe	Yes	https://maps.app.goo.gl/5pqMgfeZ5JG9kfLG8	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	No one is wearing a life jacket	\N	Fisayo 	Fisayo@publictech.studio	No	LASWA officer	\N	It's just a route used for crossing. About 30m long	Kabiyesi itomu jetty	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/kabiyesi_itomu_jetty.jpg	f
13	113	2026-03-04 13:28:37.603	Jegba Marina Badagry/Commando Jetty	6.416007847	2.876014607	Badagry	No	https://maps.app.goo.gl/uWv4o8iTXr7tL5mq8	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/113_jegba_jetty_marina_badagry.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Fisayo Balogun	fisayo@publictech.studio	Yes	LASWA list from Lanre/Ibrahim	DO NOT ASSIGN - Get from LASWA officer	\N	Jegba Marina/Commando	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/jegba_marina_badagry_commando_jetty.jpg	f
140	\N	2026-03-11 09:50:37.301	Ponton	\N	\N	N/A	No	\N	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Fisayo Balogun	fisayo@publictech.studio	No	LASWA officer	\N	Can’t find this. Not included: Location unknown	Ponton	f	Ferry facility: Less developed	\N	f
110	\N	2026-01-13 00:00:00	Oke-Agbo	\N	\N	Badagry	No	\N	Unknown	\N	\N	not_in_use	Unknown	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	All surrounded by land	Oke-Agbo	f	Not included: Outside metro	\N	f
103	4	2026-01-13 00:00:00	Muller	6.4353942	3.3890667	Apapa	Yes	https://maps.app.goo.gl/fQMA6KgLgcEKJK577	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	not_in_use	Less developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - No passenger activity	\N	Muller	f	Not included: No commercial passenger activity	\N	f
132	53	2026-01-13 00:00:00	Tekunle Epe	6.5821311	3.9908226	Epe	No	https://maps.app.goo.gl/oCGsAzGVUuQtw8vk8	Landing Point	\N	No, it is not possible	not_in_use	Less developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - Outside metro	\N	Tekunle Epe	f	Not included: Outside metro	\N	f
36	133	2026-02-20 12:23:41.701	Capital Oil/FESTAC	6.474484688	3.294149195	Amuwo Odofin	Yes	https://maps.app.goo.gl/Lr4W54e9gMKXLoPCA	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/133_capital_oil_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Sikigha Charity	isikighacharity@gmail.com	No	Public Tech Studio	Charity Sikigha	Same as FESTAC(info from Fisayo)	Capital Oil	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/capital_oil_festac.jpg	f
34	104	2026-02-20 10:59:34.482	Bonny Camp (Victoria Island)	6.435923697	3.404841004	Eti Osa	Yes	https://maps.app.goo.gl/i6CFs82tCxyJCELs8	Jetty	No, it's for private use only	No, it is not possible	not_in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/104_bonny_camp.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Sikigha Charity	isikighacharity@gmail.com	No	Public Tech Studio	Charity Sikigha	Its in the premises of the nigerian army, so its mostly restricted to the general public. However,if you are coming from tarkwa bay, and bonny camp is a closer stop to where you are headed, i believe you can make a stop there.	Bonny Camp	f	Not included: Private only	https://storage.googleapis.com/ferry-facilities/bonny_camp.jpg	f
84	118	2026-03-02 11:37:39.715	Isoda	6.426355469	3.347746321	Apapa	Yes	https://maps.app.goo.gl/1WDZaPa66xqZGYG69	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/118_isoda.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	You can charter boats to Liverpool and Itun-agan.	Isoda	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/isoda.jpg	f
105	126	2026-03-02 10:30:03.834	Number 2 (Apapa) Waterside	6.44823066	3.351415	Apapa	Yes	https://maps.app.goo.gl/KfstRmy6v99tTBSv6	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/126_number_2_waterside.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	\N	Number 2 (Apapa)	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/number_2_apapa_waterside.jpg	f
17	48	2026-03-11 09:54:54.199	Abomiti-Nla Epe	6.519404103752237	4.09519204016695	Epe	No	https://maps.app.goo.gl/FiHowyYv8VPMQS1v5	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	Unknown - Terminals/Jetties without LASWA Oversight	Fisayo Balogun	fisayo@publictech.studio	No	LASWA website	DO NOT ASSIGN - Outside metro	\N	Abomiti-Nla Epe	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/abomiti_nla_epe.jpg	f
139	\N	2026-03-11 09:50:40.388	Pashi	6.444708	2.708001	Badagry	No	https://maps.app.goo.gl/5FMjt4zB3dch7aQg9	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	Every person is wearing a life jacket	\N	Fisayo Balogun	fisayo@publictech.studio	No	LASWA officer	\N	\N	Pashi	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/pashi.jpg	f
99	69	2026-03-02 10:34:04.386	Manager	6.429986033	3.370910736	Apapa	Yes	https://maps.app.goo.gl/3MymgiMhXsb4Yoae6	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/69_manager_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Done by Fisayo - LASWA assigned facilities	\N	Manager	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/manager.jpg	f
24	116	2026-03-02 11:01:13.484	Agojedo/Agbejedo	6.417626165505482	3.3588530258308253	Apapa	Yes	https://maps.app.goo.gl/y18P8NfP8YWS5CKf8	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/116_agojedo.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	\N	Agojedo/Agbejedo	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/agojedo_agbejedo.jpg	f
27	71	2026-02-09 08:33:13.762	Allens Unit/Alex (Apapa)	6.4346659	3.3700913	Apapa	Yes	https://maps.app.goo.gl/1PqFuT8EjePVpBqH6	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/71_allens_unit___alex_apapa_jetty.jpg	Every person is wearing a life jacket	Unclear - Landing Public Access	Mr Owolabi Ibrahim	owolabiibrahim580@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	Charter locations available are Tarkwa Bay, CMS, Ogogoro village, Tomaro	Allens Unit/Alex Apapa	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/allens_unit_alex_apapa.jpg	t
113	51	2026-01-13 00:00:00	Olowo	6.4335996	3.3683852	Apapa	Yes	https://maps.app.goo.gl/FP6xesMSdzXFNca49	Jetty	Yes, anyone from the public can buy a ticket here	No, it is not possible	not_in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/51_olowo_jetty.jpg	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - No passenger activity	\N	Olowo	f	Not included: No commercial passenger activity	https://storage.googleapis.com/ferry-facilities/olowo_jetty.jpg	f
117	63	2026-01-13 00:00:00	Osborne Ferry Terminal (Ikoyi)	6.4641704	3.4174567	Eti Osa	Yes	https://maps.app.goo.gl/Z4WQEtFBaibrvCzFA	Ferry Terminal	No, it's for private use only	\N	not_in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/63_osborne_ferry_terminal.jpg	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - Private facility that passengers can't use	\N	Osborne	f	Not included: Private only	https://storage.googleapis.com/ferry-facilities/osborne_ferry_terminal.jpg	f
76	21	2026-01-13 00:00:00	Ilado Waterfront	6.413933536	3.343031377	Amuwo Odofin	Yes	https://maps.app.goo.gl/jpZ4VRW6odT4DeJK9	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - No passenger activity	\N	Ilado Waterfront	f	Not included: No commercial passenger activity	\N	f
29	28	2026-01-13 00:00:00	Apa Waterfront Badagry	6.4375869	2.8246502	Badagry	No	https://maps.app.goo.gl/rk6Euj7KZYLbPicx9	Jetty	Yes, anyone from the public can buy a ticket here	\N	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	\N	Apa Waterfront Badagry	f	Not included: Outside metro	\N	f
47	24	2026-01-13 00:00:00	Epe Marina	6.5776476	3.9775399	Epe	No	https://maps.app.goo.gl/TH9JG76R82Q36yQR9	Ferry Terminal	Yes, anyone from the public can buy a ticket here	\N	not_in_use	Developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - Outside metro	Epe Marina(gov-built) isn’t currently in use as it’s still in dev so Epe Ayetoro(id:46) is used instead. It’s a 5 min walk from each other. 	Epe Marina	f	Not included: Outside metro	\N	f
81	49	2026-03-06 21:10:07.584	Irewe Ojo	6.424470195400829	3.1529759503605135	Ojo	Yes	https://maps.app.goo.gl/JjPeZb2GhEm1ouEj8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/49_irewe_jetty_ojo.jpg	Every person is wearing a life jacket	Unknown - Terminals/Jetties without LASWA Oversight	Israel Ekundayo	israelekundayo@gmail.com	No	LASWA website	Israel Ekundayo	None	Irewe Ojo	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/irewe_ojo.jpg	f
3	20	2026-03-11 09:22:09.303	Ikorodu/Ipakodo Ferry Terminal	6.601832	3.4862304	Ikorodu	Yes	https://maps.app.goo.gl/ugw355e6nncuRRht8	Ferry Terminal	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/20_ikorodu_ferry_terminal.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Fisayo Balogun	fisayo@publictech.studio	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	\N	Ikorodu/Ipakodo	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ikorodu_ipakodo_ferry_terminal.jpg	t
26	50	2026-01-13 00:00:00	Akarakumo	6.4107553	2.9544192	Badagry	No	https://maps.app.goo.gl/aYYZaLK4MHAXthvV6	Jetty	\N	\N	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	\N	Akarakumo	f	Not included: Outside metro	\N	f
121	42	2026-02-09 09:18:04.563	Sagbokoji	6.43277977	3.376968865	Apapa	Yes	https://maps.app.goo.gl/71HF1YuEsPRRvoxKA	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/42_sagbokoji_jetty.jpg	Every person is wearing a life jacket	LASWA/State according to LASWA website	Ahmed	ahmedoladimeji62@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	The majority here are foreigners( BENIN REPUBLIC).	Sagbokoji	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/sagbokoji.jpg	t
12	68	2026-02-20 11:55:31.49	Alluvia Marine/Afisco (Lekki Phase 1)	6.4475959	3.4590768	Eti Osa	Yes	https://maps.app.goo.gl/JEudcdbSgdGoFBZPA	Jetty	No, it's for charter only	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/68_alluvia_marine_jetty_afisco_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Sikigha Charity	isikighacharity@gmail.com	No	Public Tech Studio	Charity Sikigha	Its a facility for charters to beaches and private island. No commercial boat can dock here even.	Alluvia Marine/Afisco	f	Charter only	https://storage.googleapis.com/ferry-facilities/alluvia_marine_afisco_lekki_phase_1.jpg	f
16	88	2026-03-02 10:28:19.265	Number 3 (Ajegunle) Waterside	6.450393857	3.351162411	Ajeromi/Ifelodun	Yes	https://maps.app.goo.gl/Cvenmu7UuGbo6Hxz6	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/88_3a_embassy_waterside.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	\N	Number 3 (Ajegunle)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/number_3_ajegunle_waterside.jpg	f
112	78	2026-03-11 09:21:58.952	Agboyi 1	6.579565	3.409751	Kosofe	Yes	https://maps.app.goo.gl/KiLGvu6SiKXjgWE86	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/78_olookan_stop.jpg	Only some people are wearing life jackets (not everyone)	Unknown - Not on LASWA website	Fisayo Balogun	fisayo@publictech.studio	No	Public Tech Studio	Done by Fisayo - LASWA assigned facilities	\N	Agboyi 1	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/agboyi_1.jpg	f
42	81	2026-02-25 18:38:03.243	Egbin	6.56021613	3.600195878	Ikorodu	Yes	https://maps.app.goo.gl/eowmqSouCKZAKuho8	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/81_egbin_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Charity Sikigha	isikighacharity@gmail.com	No	Public Tech Studio	Charity Sikigha	\N	Egbin	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/egbin.jpg	f
120	92	2026-02-20 21:24:09.501	Power line	6.415655161	3.247618113	Amuwo Odofin	Yes	https://maps.app.goo.gl/dGUBBjDoHVCvZ1KN8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/92_power_line.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	it is an intermediate stop	Power line	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/power_line.jpg	f
96	2	2026-01-13 00:00:00	Lekki Ferry (Lekki Phase 1)	6.447966	3.4670774	Eti Osa	Yes	https://maps.app.goo.gl/3nM7pbZ4EKGT9Gd88	Ferry Terminal	No commercial passenger activity	\N	not_in_use	Developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - No longer exists	\N	Lekki Ferry	f	Future Omi Eko	\N	t
79	138	2026-03-25 10:29:42.409	Imore Waterside	6.430224369	3.280752801	Amuwo Odofin	Yes	https://maps.app.goo.gl/B46hKrxwUiTmaibi8	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/138_imore_jetty.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Fisayo Balogun	fisayo@publictech.studio	No	Public Tech Studio	Charity Sikigha	\N	Imore	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/imore_waterside.jpg	f
116	1	2026-01-13 00:00:00	Origin	6.6071459	3.4807669	Ikorodu	Yes	https://maps.app.goo.gl/S8whyPjxG8saivQH8	Ferry Terminal	\N	Yes, it is possible	not_in_use	Developed	\N	\N	Not LASWA/State according to LASWA website	\N	\N	No	LASWA website	DO NOT ASSIGN - No passenger activity	\N	Origin	f	Not included: No commercial passenger activity	\N	f
72	3	2026-01-13 00:00:00	Ijora Landing	6.4670409	3.3703011	Apapa	Yes	https://maps.app.goo.gl/7d1DkZrX9NP1p4Zw9	Landing Point	No commercial passenger activity	\N	not_in_use	Less developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - No passenger activity	\N	Ijora Landing	f	Not included: No commercial passenger activity	\N	f
104	124	2026-03-02 10:30:57.618	Number 1A Waterside	6.44263934	3.349289318	Apapa	Yes	https://maps.app.goo.gl/2xGGXcX3DVJvraSH6	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/124_number_1a_waterside.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	\N	Number 1A	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/number_1a_waterside.jpg	f
85	37	2026-03-02 11:40:40.755	Itun Agan	6.427667306	3.359240179	Apapa	Yes	https://maps.app.goo.gl/mMko4hJawLwycRBF6	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	You can charter boats to all destination routes here.	Itun Agan	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/itun_agan.jpg	t
128	102	2026-02-20 11:02:21.799	Store	6.419085361	3.397010356	Apapa	Yes	https://maps.app.goo.gl/xuiDVNrsQ5zADRwH9	Landing Point	No, it's for charter only	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/102_store.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Sikigha Charity	isikighacharity@gmail.com	No	Public Tech Studio	Charity Sikigha	Its a landing for the people who live on or around that island. Usually people join boats headed to tarkwa bay and make a stop there. There are no designated boats for that particular location usually.	Store	f	Charter only	https://storage.googleapis.com/ferry-facilities/store.jpg	f
138	\N	2026-01-13 00:00:00	Yafin	\N	\N	Badagry	No	\N	Unknown	\N	\N	not_in_use	Unknown	\N	\N	LASWA/State according to LASWA website	\N	\N	No	Unknown	DO NOT ASSIGN - Outside metro	All surrounded by land	Yafin	f	Not included: Outside metro	\N	f
134	56	2026-01-13 00:00:00	Topo Island Badagry	6.4085379	2.9313645	Badagry	No	https://maps.app.goo.gl/KR2pdEjQsAgyyoqD8	Jetty	Yes, anyone from the public can buy a ticket here	No, it is not possible	not_in_use	Developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - Outside metro	\N	Topo Island Badagry	f	Not included: Outside metro	\N	f
88	\N	2026-03-03 09:43:53.835	Iya Afin Jetty	6.445606177	2.8608538	Epe	No	https://maps.app.goo.gl/n16X3Rc8SQV7USi87	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Mr Kazeem	Kazeemfayemi0@gmail.com	Yes	LASWA list from Lanre/Ibrahim	DO NOT ASSIGN - Get from LASWA officer	Charter is only available to izigi	Iya Afin	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/iya_afin_jetty.jpg	f
46	\N	2026-02-25 12:36:25.075	Epe Ayetoro Jetty	6.577579	3.975230	Epe	No	https://maps.app.goo.gl/1mYfTiCYiLnNpkFh8	Ferry Terminal	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com	Yes	LASWA list from Lanre/Ibrahim	DO NOT ASSIGN - Get from LASWA officer	Charter is to anywhere in Lagos 	Epe Ayetoro	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/epe_ayetoro_jetty.jpg	f
71	47	2026-02-11 09:17:23.455	Ijon	6.563707	3.20189717	Alimosho	Yes	https://maps.app.goo.gl/582j7DuHziGC7M7U8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	\N	Every person is wearing a life jacket	Unknown - Terminals/Jetties without LASWA Oversight	Mrs Adeyeye Omotolani Felicia	omotolaniadeyeye@gmail.com	Yes	LASWA website	DO NOT ASSIGN - Get from LASWA officer	Charter services to Ijon Odo	Ijon	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/ijon.jpg	f
52	73	2026-03-11 09:20:53.622	Ferry Port/Checkpoint	6.4405074	3.4041996	Eti Osa	Yes	https://maps.app.goo.gl/iKvGKUbU257FGiwe9	Landing Point	No, it's for charter only	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/73_ferry_port_checkpoint_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Fisayo Balogun	fisayo@publictech.studio	No	Public Tech Studio	Charity Sikigha	Charter is possible to anywhere in Lagos	Ferry Port/Checkpoint	f	Charter only	https://storage.googleapis.com/ferry-facilities/ferry_port_checkpoint.jpg	f
147	\N	2026-03-02 10:29:42.671	Number 2 (Ajegunle) Waterside/Kumuyi Street(Ajegunle)	6.448440081	3.350893109	Ajeromi/Ifelodun	Yes	https://maps.app.goo.gl/vkdZWat176ns2UcL9	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/131_kumuyi_street__ajegunle_.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	\N	Number 2 Waterside/Kumuyi Street(Ajegunle)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/number_2_ajegunle_waterside_kumuyi_street_ajegunle.jpg	f
149	\N	2026-03-02 10:28:45.06	Number 1 (Ajegunle) Waterside	6.4463	3.3500	Ajeromi/Ifelodun	Yes	https://maps.app.goo.gl/Rc4tEqfxhHk4aA797	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	No one is wearing a life jacket	\N	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Contractor - Ayodeji Adesegun\n	\N	\N	Number 1 (Ajegunle)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/number_1_ajegunle_waterside.jpg	f
151	\N	2026-03-02 10:29:06.404	Number 1 (Apapa) Waterside	6.4461	3.3505	Apapa	Yes	https://maps.app.goo.gl/Enyf5cMS1cfYPYUm9	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	\N	No one is wearing a life jacket	\N	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Contractor - Ayodeji Adesegun	\N	\N	Number 1 (Apapa)	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/number_1_apapa_waterside.jpg	f
4	112	2026-03-11 09:50:26.594	Port Novo (Benin Republic)	6.466004874097848	2.6233855442023355	Outside Lagos: Benin Republic	No	https://maps.app.goo.gl/varoLHDruS5eFPJcA	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/112_port_novo.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Fisayo Balogun	fisayo@publictech.studio	No	Public Tech Studio	DO NOT ASSIGN - Outside metro	\N	Port Novo	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/port_novo_benin_republic.jpg	f
32	72	2026-02-12 10:05:17.717	Bariga Waterfront	6.528356	3.3999032	Shomolu	Yes	https://maps.app.goo.gl/3MxDTfA7pX6eMHFi6	Jetty	No, it's for charter only	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/72_bariga_waterfront_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Mr Joseph Nnaji	Donjoe252@gmail.com	Yes	LASWA list from Lanre/Ibrahim	DO NOT ASSIGN - Get from LASWA officer	You can charter to anywhere in Lagos state.	Bariga	f	Charter only	https://storage.googleapis.com/ferry-facilities/bariga_waterfront.jpg	t
135	98	2026-02-24 10:27:03.291	Uncle Ben	6.40810007	3.215426604	Amuwo Odofin	Yes	https://maps.app.goo.gl/kUCk8zApHBjKyeYp6	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/98_uncle_ben_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	it is an intermediate stop	Uncle Ben	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/uncle_ben.jpg	f
97	6	2026-01-13 00:00:00	Liberty	6.452604	3.3840325	Lagos Island	Yes	https://maps.app.goo.gl/qztS4s8s4QsCS9gZ9	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	not_in_use	Developed	\N	\N	Unknown - Not on LASWA website	\N	\N	No	Public Tech Studio	DO NOT ASSIGN - No passenger activity	\N	Liberty	f	Not included: No commercial passenger activity	\N	f
59	83	2026-02-27 10:41:35.217	Ibasa	6.424950503	3.255345985	Amuwo Odofin	Yes	https://maps.app.goo.gl/vYxgUUNa5G5KFT3L8	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/83_ibasa_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Israel Ekundayo	israelekundayo@gmail.com	No	Public Tech Studio	Israel Ekundayo	\N	Ibasa	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/ibasa.jpg	t
129	38	2026-03-06 14:10:18.12	Itomoro	6.418094084	3.362453877	Apapa	Yes	https://maps.app.goo.gl/RkMC1bmDt4zcemCa8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	\N	Every person is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	Boats are chartered at 50,000 naira to Liverpool	Itomoro	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/itomoro.jpg	f
41	105	2026-02-13 09:37:09.919	Egan Landing	6.447364946	3.141547596	Ojo	Yes	https://maps.app.goo.gl/u97wxexEK53QzjUp8	Landing Point	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/105_egan_landing.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Mr Olowoseelu Festus	Remiolusoji7@gmail.com	No	Public Tech Studio	Done by Fisayo - LASWA assigned facilities	Charter is only to Etegbin	Egan Landing	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/egan_landing.jpg	f
43	57	2026-01-13 00:00:00	Ejirin Agbowa/Ikosi	6.609682473	3.898715868	Epe	No	https://maps.app.goo.gl/TxjzJjT2QcyBTUGt6	Jetty	\N	\N	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	\N	Ejirin Agbowa/Ikosi	f	Not included: Outside metro	\N	f
18	139	2026-02-09 14:37:11.021	Abule Osun	6.437043497	3.23667811	Amuwo Odofin	Yes	https://maps.app.goo.gl/5y9FMFWLzVk23ZFk6	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/139_abule_osun.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Mr Arowolo Olayinka	olayinkamubo26@gmail.com	Yes	LASWA list from Lanre/Ibrahim	DO NOT ASSIGN - Get from LASWA officer	\N	Abule Osun	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/abule_osun.jpg	f
11	111	2026-02-18 12:14:49.617	Law School (Victoria Island)	6.439555892	3.425330345	Eti Osa	Yes	https://maps.app.goo.gl/n2SbZaDs2LSwDJJL6	Ferry Terminal	No, it's for charter only	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/111_law_school__vi_.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Sikigha Charity	isikighacharity@gmail.com	No	Public Tech Studio	Charity Sikigha	This facility is strictly private. All of the boats at here are privately chartered.	Law School	f	Charter only	https://storage.googleapis.com/ferry-facilities/law_school_victoria_island.jpg	f
122	109	2026-02-24 10:52:57.65	Salt Beach	6.406064982	3.2236361	Amuwo Odofin	Yes	https://maps.app.goo.gl/bTdahmpBfzxqeT8XA	Jetty	Yes, anyone from the public can buy a ticket here	Yes, it is possible	in_use	Developed	https://stears-flourish-data.s3.amazonaws.com/109_salt_beach_jetty.jpg	Every person is wearing a life jacket	Unknown - Not on LASWA website	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	No	Public Tech Studio	Victor Kokodoko	it is an intermediate stop	Salt Beach	f	Ferry facility: Developed	https://storage.googleapis.com/ferry-facilities/salt_beach.jpg	f
124	127	2026-03-02 10:31:29.474	Second Badagry	6.441039888	3.348588954	Ajeromi/Ifelodun	Yes	https://maps.app.goo.gl/H1hc4DGtHLHE6SCc9	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	in_use	Less developed	https://stears-flourish-data.s3.amazonaws.com/127_second_badagry.jpg	No one is wearing a life jacket	Unknown - Not on LASWA website	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	No	Public Tech Studio	Ayodeji Adesegun	\N	Second Badagry	f	Ferry facility: Less developed	https://storage.googleapis.com/ferry-facilities/second_badagry.jpg	f
111	\N	2026-01-13 00:00:00	Okun Kobo	\N	\N	Ojo	Yes	https://maps.app.goo.gl/E9kZEJvicYyo9bhz8	Landing Point	Yes, anyone from the public can buy a ticket here	No, it is not possible	not_in_use	Less developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Location unknown	Can’t find this. Not included: Location unknown	Okun Kobo	f	Not included: Location unknown	\N	f
108	9	2026-01-13 00:00:00	Oju-Agemo Imota	6.5733152	3.6610244	Ikorodu	Yes	https://maps.app.goo.gl/urY3FKoeGkJs1qra7	Jetty	Yes, anyone from the public can buy a ticket here	No, it is not possible	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - No passenger activity	\N	Oju-Agemo Imota	f	Not included: No commercial passenger activity	\N	f
48	52	2026-01-13 00:00:00	Epeme	6.4161449	3.0504744	Badagry	No	https://maps.app.goo.gl/JLmoH6FoJ1wVfXeU8	Jetty	\N	\N	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	\N	Epeme	f	Not included: Outside metro	\N	f
49	46	2026-01-13 00:00:00	Eputu	6.4828966	3.7151988	Ibeju Lekki	No	https://maps.app.goo.gl/tfBuxayRnSey5ZFi7	Jetty	\N	\N	not_in_use	Developed	\N	\N	Unknown - Terminals/Jetties without LASWA Oversight	\N	\N	No	LASWA website	DO NOT ASSIGN - Outside metro	\N	Eputu	f	Not included: Outside metro	\N	f
\.


--
-- Data for Name: facility_destinations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.facility_destinations (facility_id, destination_id, modified_at, facility_destination_id, is_charter) FROM stdin;
36	98	2026-02-20 12:23:42.053	178	t
52	130	2026-03-11 09:20:53.519	459	t
126	221	2026-03-11 11:58:41.325	508	t
10	200	2026-02-09 10:10:58.795	30	f
100	62	2026-03-11 13:10:37.229	511	t
100	122	2026-03-11 13:10:37.229	512	t
100	77	2026-03-11 13:10:37.229	513	t
90	10	2026-03-05 02:49:21.328	390	t
54	130	2026-03-24 12:12:16.864	514	f
79	222	2026-03-25 10:29:42.261	515	f
79	59	2026-03-25 10:29:42.304	516	t
13	92	2026-03-04 13:28:37.885	375	f
74	135	2026-03-04 20:23:14.487	380	f
74	122	2026-03-04 20:23:14.548	381	f
74	107	2026-03-04 20:23:14.604	382	f
74	89	2026-03-04 20:23:14.668	383	f
74	73	2026-03-04 20:23:14.725	384	f
89	107	2026-03-04 20:28:40.008	385	f
89	135	2026-03-04 20:28:40.072	386	f
89	122	2026-03-04 20:28:40.131	387	f
89	73	2026-03-04 20:28:40.188	388	f
89	74	2026-03-04 20:28:40.244	389	f
78	10	2026-03-05 03:06:10.825	394	f
78	84	2026-03-05 03:06:10.891	395	f
78	85	2026-03-05 03:06:10.948	396	f
64	10	2026-03-05 03:08:43.32	397	f
64	84	2026-03-05 03:08:43.383	398	f
64	85	2026-03-05 03:08:43.439	399	f
129	90	2026-03-06 14:10:18.285	438	f
129	78	2026-03-06 14:10:18.351	439	f
129	64	2026-03-06 14:10:18.409	440	f
129	85	2026-03-06 14:10:18.468	441	f
129	24	2026-03-06 14:10:18.528	442	f
129	10	2026-03-06 14:10:18.59	443	f
129	220	2026-03-06 14:10:18.684	444	f
19	107	2026-03-06 21:09:43.001	445	f
1	5	2026-03-11 08:56:51.01	454	f
1	6	2026-03-11 08:56:51.054	455	f
1	3	2026-03-11 08:56:51.083	456	f
1	4	2026-03-11 08:56:51.115	457	f
1	13	2026-03-11 08:56:51.146	458	f
4	1	2026-03-11 09:50:26.181	484	f
4	13	2026-03-11 09:50:26.252	485	f
220	85	2026-03-09 13:32:35.935	450	t
220	64	2026-03-09 13:32:35.992	451	t
220	90	2026-03-09 13:32:35.878	449	t
220	10	2026-03-09 13:32:35.821	448	t
220	129	2026-03-09 13:32:35.756	447	t
220	78	2026-03-09 13:32:36.118	452	t
220	24	2026-03-09 13:32:36.175	453	t
27	99	2026-02-09 08:33:13.909	11	f
27	91	2026-02-09 08:33:13.972	12	f
27	121	2026-02-09 08:33:14.031	13	f
121	27	2026-02-09 09:18:04.694	14	f
10	27	2026-02-09 10:10:58.736	29	f
10	35	2026-02-09 10:10:58.858	31	f
10	84	2026-02-09 10:10:58.976	33	f
10	6	2026-02-09 10:10:59.094	35	f
10	121	2026-02-09 10:10:59.155	36	f
10	130	2026-02-09 10:10:59.272	38	f
10	57	2026-02-09 10:10:59.33	39	f
10	3	2026-02-09 10:10:59.392	40	f
10	129	2026-02-09 10:10:59.528	42	f
70	30	2026-02-09 13:40:49.502	45	f
70	59	2026-02-09 13:40:49.566	46	f
70	62	2026-02-09 13:40:49.634	47	f
101	92	2026-05-08 17:08:56.616548	655	f
15	7	2026-05-08 17:08:56.616548	657	f
31	7	2026-05-08 17:08:56.616548	658	f
101	6	2026-05-08 17:08:56.616548	659	f
6	5	2026-05-08 17:08:56.616548	660	f
69	7	2026-05-08 17:08:56.616548	661	f
200	6	2026-05-08 17:08:56.616548	662	f
5	3	2026-05-08 17:08:56.616548	663	f
7	2	2026-05-08 17:08:56.616548	664	f
221	126	2026-03-11 11:59:22.673	510	t
14	12	2026-02-10 09:30:34.252	54	f
4	18	2026-03-11 09:50:26.283	486	f
4	101	2026-03-11 09:50:26.363	488	f
4	92	2026-03-11 09:50:26.422	490	f
4	6	2026-03-11 09:50:26.451	491	f
4	57	2026-03-11 09:50:26.48	492	f
4	10	2026-03-11 09:50:26.509	493	f
145	63	2026-03-11 09:50:34.237	494	f
139	4	2026-03-11 09:50:40.269	498	f
146	4	2026-03-11 09:50:42.29	501	f
157	88	2026-03-11 09:50:44.163	502	f
144	71	2026-03-11 09:50:50.562	505	f
155	46	2026-03-11 09:50:54.93	506	f
200	86	2026-03-06 11:39:31.421	419	f
200	2	2026-03-06 11:39:31.537	421	f
200	58	2026-03-06 11:39:31.594	422	f
81	107	2026-03-06 21:10:07.709	446	f
22	23	2026-03-11 09:21:21.343	460	f
22	21	2026-03-11 09:21:21.374	461	f
22	112	2026-03-11 09:21:21.406	462	f
74	9	2026-04-08 15:19:32.085424	522	f
10	2	2026-05-08 17:08:56.616548	669	f
10	85	2026-05-08 17:08:56.616548	670	f
18	80	2026-05-08 17:08:56.616548	671	f
101	36	2026-05-08 17:08:56.616548	672	f
92	36	2026-05-08 17:08:56.616548	673	f
107	73	2026-05-08 17:08:56.616548	674	f
70	120	2026-02-09 13:40:49.695	48	f
18	4	2026-02-09 14:37:11.229	49	f
18	13	2026-02-09 14:37:11.291	50	f
15	2	2026-02-10 09:02:13.994	52	f
15	10	2026-02-10 09:02:14.062	53	f
14	7	2026-02-10 09:30:34.313	55	f
14	2	2026-02-10 09:30:34.372	56	f
18	139	2026-02-09 14:37:11.354	51	f
18	140	\N	57	f
69	2	2026-02-10 12:16:41.766	60	f
69	8	2026-02-10 12:16:41.827	61	f
109	31	2026-02-10 12:58:18.582	63	f
31	109	2026-02-10 13:56:47.999	64	f
9	81	2026-02-11 12:55:51.189	66	f
9	74	2026-02-11 12:55:51.249	67	f
9	77	2026-02-11 12:55:51.367	69	f
9	19	2026-02-11 12:55:51.425	70	f
23	20	2026-02-12 08:03:10.991	71	f
23	21	2026-02-12 08:03:11.053	72	f
23	22	2026-02-12 08:03:11.113	73	f
32	96	2026-02-12 10:05:17.863	74	t
141	51	2026-02-13 09:36:51.195	75	f
41	51	2026-02-13 09:37:10.059	76	f
51	141	2026-02-13 09:38:14.534	77	f
51	41	2026-02-13 09:38:14.596	78	f
142	83	2026-02-13 10:30:25.914	79	f
83	142	2026-02-13 10:31:09.34	80	f
34	6	2026-02-20 10:59:34.618	140	t
70	125	2026-02-16 16:41:59.050227	90	f
71	144	2026-02-16 17:43:32.60621	93	f
63	145	2026-02-16 17:43:54.669956	94	f
23	112	2026-02-17 12:53:31.475463	95	f
130	52	2026-02-18 12:09:43.156	98	t
11	6	2026-02-18 12:14:49.773	99	t
11	52	2026-02-18 12:14:49.837	100	t
11	33	2026-02-18 12:14:49.926	101	t
11	2	2026-02-18 12:14:49.985	102	t
11	60	2026-02-18 12:14:50.045	103	t
11	77	2026-02-18 12:14:50.106	104	t
11	93	2026-02-18 12:14:50.165	105	t
11	117	2026-02-18 12:14:50.225	106	t
11	122	2026-02-18 12:14:50.284	107	t
11	130	2026-02-18 12:14:50.344	108	t
73	89	2026-02-18 21:45:25.018	121	f
73	107	2026-02-18 21:45:25.08	122	f
67	38	2026-02-19 10:42:14.359	123	f
11	67	2026-02-18 12:14:50.404	109	t
38	67	2026-02-09 11:58:46.825	43	f
60	120	2026-02-20 10:13:29.27	128	f
60	119	2026-02-20 10:13:29.333	129	f
60	114	2026-02-20 10:13:29.39	130	f
60	107	2026-02-20 10:13:29.45	131	f
60	100	2026-02-20 10:13:29.507	132	f
60	93	2026-02-20 10:13:29.565	133	f
60	77	2026-02-20 10:13:29.622	134	f
60	70	2026-02-20 10:13:29.68	135	f
60	62	2026-02-20 10:13:29.737	136	f
60	59	2026-02-20 10:13:29.794	137	f
60	125	2026-02-20 10:13:29.851	138	f
60	30	2026-02-20 10:13:29.908	139	f
106	6	2026-02-20 11:01:57.559	141	t
128	6	2026-02-20 11:02:21.911	142	t
44	30	2026-02-20 11:27:03.553	143	f
44	59	2026-02-20 11:27:03.612	144	f
44	125	2026-02-20 11:27:03.671	145	f
44	60	2026-02-20 11:27:03.73	146	f
44	62	2026-02-20 11:27:03.79	147	f
44	70	2026-02-20 11:27:03.849	148	f
44	114	2026-02-20 11:27:03.908	149	f
44	93	2026-02-20 11:27:03.965	150	f
62	44	2026-02-20 11:47:04.77	152	f
62	59	2026-02-20 11:47:04.828	153	f
62	60	2026-02-20 11:47:04.885	154	f
62	93	2026-02-20 11:47:04.998	156	f
62	114	2026-02-20 11:47:05.111	158	f
62	119	2026-02-20 11:47:05.168	159	f
62	120	2026-02-20 11:47:05.225	160	f
62	125	2026-02-20 11:47:05.284	161	f
12	122	2026-02-20 11:55:31.636	162	t
12	130	2026-02-20 11:55:31.698	163	t
12	134	2026-02-20 11:55:31.755	164	t
36	101	2026-02-20 12:23:41.858	175	f
36	92	2026-02-20 12:23:41.92	176	f
36	10	2026-02-20 12:23:41.984	177	f
5	1	2026-05-08 17:09:49.859732	676	f
120	30	2026-02-20 21:24:09.647	181	f
120	59	2026-02-20 21:24:09.708	182	f
120	70	2026-02-20 21:24:09.766	183	f
120	114	2026-02-20 21:24:09.825	184	f
120	119	2026-02-20 21:24:09.883	185	f
120	125	2026-02-20 21:24:09.941	186	f
120	93	2026-02-20 21:24:09.999	187	f
120	60	2026-02-20 21:24:10.055	188	f
120	62	2026-02-20 21:24:10.114	189	f
114	62	2026-02-20 21:24:21.671	190	f
114	60	2026-02-20 21:24:21.733	191	f
114	59	2026-02-20 21:24:21.792	192	f
114	30	2026-02-20 21:24:21.854	193	f
114	70	2026-02-20 21:24:21.914	194	f
114	119	2026-02-20 21:24:21.974	195	f
114	120	2026-02-20 21:24:22.034	196	f
114	125	2026-02-20 21:24:22.094	197	f
114	93	2026-02-20 21:24:22.153	198	f
119	60	2026-02-20 21:32:29.982	199	f
119	62	2026-02-20 21:32:30.043	200	f
119	30	2026-02-20 21:32:30.105	201	f
119	44	2026-02-20 21:32:30.161	202	f
119	70	2026-02-20 21:32:30.218	203	f
119	120	2026-02-20 21:32:30.275	204	f
119	125	2026-02-20 21:32:30.331	205	f
119	114	2026-02-20 21:32:30.405	206	f
119	93	2026-02-20 21:32:30.462	207	f
93	30	2026-02-20 21:50:34.763	208	f
93	60	2026-02-20 21:50:34.826	209	f
93	62	2026-02-20 21:50:34.886	210	f
93	59	2026-02-20 21:50:34.946	211	f
93	70	2026-02-20 21:50:35.006	212	f
93	114	2026-02-20 21:50:35.064	213	f
93	120	2026-02-20 21:50:35.124	214	f
93	125	2026-02-20 21:50:35.183	215	f
93	119	2026-02-20 21:50:35.241	216	f
80	18	2026-02-24 09:37:00.616	226	f
135	73	2026-02-24 10:27:03.454	227	f
135	74	2026-02-24 10:27:03.521	228	f
135	77	2026-02-24 10:27:03.577	229	f
135	89	2026-02-24 10:27:03.634	230	f
135	107	2026-02-24 10:27:03.69	231	f
135	122	2026-02-24 10:27:03.746	232	f
122	73	2026-02-24 10:52:57.796	233	f
122	74	2026-02-24 10:52:57.862	234	f
122	77	2026-02-24 10:52:57.922	235	f
122	89	2026-02-24 10:52:57.982	236	f
122	135	2026-02-24 10:52:58.042	237	f
122	107	2026-02-24 10:52:58.102	238	f
8	69	2026-02-25 09:23:47.891	240	f
152	86	2026-02-25 09:57:54.335	244	f
46	153	2026-02-25 12:36:25.272	245	f
46	154	2026-02-25 12:36:25.363	246	f
46	17	2026-02-25 12:36:25.421	247	f
46	155	2026-02-25 12:36:25.51	248	f
101	146	2026-02-25 16:58:08.292	249	f
101	139	2026-02-25 16:58:08.352	250	f
101	4	2026-02-25 16:58:08.41	251	f
58	32	2026-02-25 17:58:58.937	255	f
58	6	2026-02-25 17:58:58.996	256	f
36	102	2026-02-20 12:23:42.114	179	t
58	200	2026-02-25 17:58:58.762	252	f
86	200	2026-02-25 09:24:35.484	243	f
62	100	2026-02-20 11:47:05.055	157	t
130	6	2026-02-18 12:09:43.094	97	f
42	6	2026-02-25 18:38:03.504	265	f
92	6	2026-02-25 18:44:57.438	266	f
92	10	2026-02-25 18:44:57.499	267	f
92	101	2026-02-25 18:44:57.557	268	f
92	70	2026-02-25 18:44:57.616	269	f
92	13	2026-02-25 18:44:57.789	272	f
92	4	2026-02-25 18:44:57.869	273	f
77	135	2026-02-26 11:19:07.986	275	f
77	122	2026-02-26 11:19:08.048	276	f
77	107	2026-02-26 11:19:08.107	277	f
77	89	2026-02-26 11:19:08.169	278	f
77	73	2026-02-26 11:19:08.23	279	f
77	74	2026-02-26 11:19:08.29	280	f
107	77	2026-02-27 09:23:22.484	281	f
107	60	2026-02-27 09:23:22.551	282	f
107	74	2026-02-27 09:23:22.616	283	f
107	81	2026-02-27 09:23:22.679	284	f
107	19	2026-02-27 09:23:22.74	285	f
107	89	2026-02-27 09:23:22.805	286	f
59	70	2026-02-27 10:41:35.371	287	f
125	70	2026-02-27 10:42:49.509	288	f
30	70	2026-02-27 10:43:37.371	289	f
6	10	2026-02-27 12:14:22.586	296	f
6	130	2026-02-27 12:14:22.706	298	f
6	13	2026-02-27 12:14:22.764	299	f
6	4	2026-02-27 12:14:22.821	300	f
6	1	2026-02-27 12:14:22.936	302	f
6	2	2026-02-27 12:14:22.993	303	f
6	3	2026-02-27 12:14:23.049	304	f
6	106	2026-02-27 12:14:23.11	305	f
35	16	2026-03-02 10:27:43.889	306	f
16	35	2026-03-02 10:28:19.383	307	f
149	151	2026-03-02 10:28:45.184	308	f
151	149	2026-03-02 10:29:06.52	309	f
147	105	2026-03-02 10:29:42.786	310	f
105	147	2026-03-02 10:30:03.964	311	f
104	124	2026-03-02 10:30:57.737	312	f
104	102	2026-03-02 10:30:57.794	313	f
124	104	2026-03-02 10:31:29.595	314	f
102	104	2026-03-02 10:31:41.575	315	f
91	27	2026-03-02 10:33:37.437	316	f
99	27	2026-03-02 10:34:04.519	317	f
5	6	2026-03-02 10:38:10.524	318	f
55	75	2026-03-02 10:48:08.672	319	f
75	55	2026-03-02 10:50:06.132	320	f
24	90	2026-03-02 11:01:13.636	321	f
24	78	2026-03-02 11:01:13.698	322	f
24	64	2026-03-02 11:01:13.755	323	f
24	10	2026-03-02 11:01:13.813	324	f
24	85	2026-03-02 11:01:13.869	325	f
84	85	2026-03-02 11:37:39.866	344	f
84	10	2026-03-02 11:37:39.93	345	f
84	78	2026-03-02 11:37:39.99	346	f
84	64	2026-03-02 11:37:40.051	347	f
85	10	2026-03-02 11:40:40.907	348	f
85	78	2026-03-02 11:40:40.968	349	f
85	64	2026-03-02 11:40:41.026	350	f
85	84	2026-03-02 11:40:41.083	351	f
85	90	2026-03-02 11:40:41.141	352	f
85	129	2026-03-02 11:40:41.2	353	f
85	24	2026-03-02 11:40:41.26	354	f
57	18	2026-03-03 09:06:04.908	355	f
57	92	2026-03-03 09:06:04.973	356	f
57	101	2026-03-03 09:06:05.032	357	f
57	10	2026-03-03 09:06:05.091	358	f
57	6	2026-03-03 09:06:05.15	359	f
57	1	2026-03-03 09:06:05.229	360	f
156	18	2026-03-03 09:06:24.029	361	f
156	92	2026-03-03 09:06:24.092	362	f
156	101	2026-03-03 09:06:24.161	363	f
156	10	2026-03-03 09:06:24.223	364	f
156	6	2026-03-03 09:06:24.286	365	f
156	1	2026-03-03 09:06:24.348	366	f
88	157	2026-03-03 09:43:54.011	367	f
7	3	2026-03-03 17:48:14.768	368	f
7	15	2026-03-03 17:48:14.845	369	f
7	31	2026-03-03 17:48:14.907	370	f
7	14	2026-03-03 17:48:14.969	371	f
7	69	2026-03-03 17:48:15.032	372	f
37	70	2026-02-25 18:50:46.348	274	t
92	130	2026-02-25 18:44:57.674	270	t
92	67	2026-02-25 18:44:57.731	271	t
6	200	2026-02-27 12:14:22.878	301	f
112	23	2026-03-11 09:21:58.805	463	f
112	22	2026-03-11 09:21:58.835	464	f
112	21	2026-03-11 09:21:58.864	465	f
21	23	2026-03-11 09:22:01.283	466	f
21	112	2026-03-11 09:22:01.312	467	f
21	22	2026-03-11 09:22:01.342	468	f
20	23	2026-03-11 09:22:05.714	469	f
3	7	2026-03-11 09:22:09.039	470	f
3	6	2026-03-11 09:22:09.07	471	f
3	10	2026-03-11 09:22:09.098	472	f
3	1	2026-03-11 09:22:09.127	473	f
3	2	2026-03-11 09:22:09.157	474	f
3	5	2026-03-11 09:22:09.187	475	f
3	12	2026-03-11 09:22:09.216	476	f
2	3	2026-03-11 09:22:11.212	477	f
2	14	2026-03-11 09:22:11.241	478	f
2	7	2026-03-11 09:22:11.299	480	f
2	200	2026-03-11 09:22:11.328	481	f
2	6	2026-03-11 09:22:11.358	482	f
2	10	2026-03-11 09:22:11.388	483	f
222	79	2026-04-08 15:00:20.251399	517	f
200	10	2026-04-08 15:13:13.170622	519	f
73	74	2026-04-08 15:14:52.09804	520	f
81	9	2026-04-08 15:18:57.460462	521	f
86	152	2026-04-08 15:21:14.458827	523	f
\.


--
-- Data for Name: facility_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.facility_submissions (facility_submission_id, facility_id, submitted_at, facility_name, facility_type, commercial_transport, charter_services, life_jackets, contact_name, contact_email, additional_notes, status, pending_destinations) FROM stdin;
23	121	2026-02-09 09:18:03.963+00	Sagbokoji	Jetty	t	t	Every person is wearing a life jacket	Ahmed	ahmedoladimeji62@gmail.com	The majority here are foreigners( BENIN REPUBLIC).	applied	\N
24	10	2026-02-09 10:10:52.938+00	Liverpool (Apapa)	Jetty	t	t	Every person is wearing a life jacket	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	\N	applied	\N
25	10	2026-02-09 10:10:58.586+00	Liverpool (Apapa)	Jetty	t	t	Every person is wearing a life jacket	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	\N	applied	\N
26	38	2026-02-09 11:58:46.425+00	Coconut Landing	Landing Point	t	t	Every person is wearing a life jacket	Mr Joseph 	None	\N	applied	\N
27	75	2026-02-09 12:25:39.294+00	IKO/Temidire	Jetty	t	f	Every person is wearing a life jacket	Mr Adebayo Abidun	None	\N	applied	\N
28	70	2026-02-09 13:40:48.652+00	Ijegun Egba	Ferry Terminal	t	t	Every person is wearing a life jacket	Mr Damilola Hassan	damexsy@gmail.com	You can also get to Ilashe beach from here by entering Ibeshe boat but paying an extra extra fee.	applied	\N
29	18	2026-02-09 14:37:10.306+00	Abule Osun	Jetty	t	t	Every person is wearing a life jacket	Mr Arowolo Olayinka	olayinkamubo26@gmail.com	\N	applied	\N
31	14	2026-02-10 09:30:33.036+00	Offin, Ikorodu	Jetty	t	t	Every person is wearing a life jacket	Mr Olabinjo Lateef	olabinjolafet@gmail.com	\N	applied	\N
34	8	2026-02-10 12:17:05.532+00	Badore Ferry Terminal	Jetty	t	f	Every person is wearing a life jacket	Mr Michael Diyepiriwei	diyemichael@gmail.com	\N	applied	\N
35	109	2026-02-10 12:58:18.181+00	Oke Ira Nla (Ajah)	Jetty	t	t	Every person is wearing a life jacket	Mr Ismail	ismailolalekan68@yahoo.com	\N	applied	\N
36	31	2026-02-10 13:56:47.132+00	Baiyeku	Jetty	t	t	Every person is wearing a life jacket	Mr Bassey Iniobong	iniobong04@gmail.com	Charter is limited to ijede and oke Ira jetties	applied	\N
37	71	2026-02-11 09:17:22.764+00	Ijon	Landing Point	t	t	Every person is wearing a life jacket	Mrs Adeyeye Omotolani Felicia	omotolaniadeyeye@gmail.com	Charter services to Ijon Odo	applied	\N
40	23	2026-02-12 08:03:10.107+00	Agboyi Ketu	Jetty	t	f	Every person is wearing a life jacket	Otudero Taiwo Oluwayemisi	None	\N	applied	\N
41	32	2026-02-12 10:05:17.012+00	Bariga Waterfront	Jetty	f	t	Every person is wearing a life jacket	Mr Joseph Nnaji	Donjoe252@gmail.com	You can charter to anywhere in Lagos state.	applied	\N
42	141	2026-02-13 09:36:50.425+00	Isofin	Landing Point	t	t	Every person is wearing a life jacket	Mr Olowoseelu Festus	Remiolusoji7@gmail.com	Charter is only to Etegbin	applied	\N
43	41	2026-02-13 09:37:09.681+00	Egan Landing	Landing Point	t	t	Every person is wearing a life jacket	Mr Olowoseelu Festus	Remiolusoji7@gmail.com	Charter is only to Etegbin	applied	\N
44	51	2026-02-13 09:38:14.178+00	Etegbin	Landing Point	t	t	Every person is wearing a life jacket	Mr olowoseelu festus	Remiolusoji7@gmail.com	Charter is only to those 2 locations 	applied	\N
45	142	2026-02-13 10:30:25.17+00	Iteku	Landing Point	t	t	Every person is wearing a life jacket	Mr Amodu Falilu	Amoduoluwafemi64@yahoo.com	Charter is only possible to destination 	applied	\N
33	69	2026-02-10 12:16:41.422+00	Ijede/Tarzan	Jetty	t	f	Every person is wearing a life jacket	Mr Michael Diyepiriwei	diyemichael@gmail.com	\N	applied	\N
32	69	2026-02-10 12:15:37.845+00	Ijede/Tarzan	Jetty	t	f	Every person is wearing a life jacket	Mr Michael Diyepiriwei	diyemichael@gmail.com	\N	applied	\N
46	83	2026-02-13 10:31:08.993+00	Isashi Landing	Landing Point	t	t	Every person is wearing a life jacket	Mr Amodu Falilu	Amoduoluwafemi64@yahoo.com	Charter is only possible to Destination 	applied	\N
38	63	2026-02-11 10:29:59.312+00	Igando Landing/Ishitu	Landing Point	t	t	Every person is wearing a life jacket	Mr Komolafe Michael Temitope	komolafetemitope5555@gmail.com	Charter services is only to Totowu	applied	\N
30	15	2026-02-10 09:02:13.132+00	Ibeshe/Thesaurus Ferry Terminal	Ferry Terminal	t	t	Every person is wearing a life jacket	ISHOLA TAIWO OLANREWAJU 	isholataiwoolanrewajutiems@gmail.com	\N	applied	\N
22	27	2026-02-09 08:33:13.072+00	Allens Unit/Alex Apapa	Landing Point	t	t	Every person is wearing a life jacket	Mr Owolabi Ibrahim	owolabiibrahim580@gmail.com	Charter locations available are Tarkwa Bay, CMS, Ogogoro village, Tomaro	applied	\N
39	9	2026-02-11 12:55:50.287+00	Ebute Ojo/Sifax Ferry Terminal	Ferry Terminal	t	t	Every person is wearing a life jacket	Mr Pascal	N/a	\N	applied	\N
21	140	2026-02-07 20:58:23.548+00	Ponton	Landing Point	t	t	Every person is wearing a life jacket	Sample	sample@ptech.studio	sample, tbd	applied	\N
49	5	2026-02-16 16:31:41.604+00	Apapa Flour Mill	Jetty	t	t	Only some people are wearing life jackets (not everyone)	Sikigha Charity	isikighacharity@gmail.com	The boats to Ikorodu operate only in the morning and evening due to low \npassenger demand from the terminal. Additionally, many passengers are reluctant to provide \ntheir information for the manifest, some passengers neglect to use life jackets, and ferries do not \noperate on weekends, leaving only small boats in service. 	applied	\N
50	130	2026-02-16 17:12:57.715+00	Tarkwa Bay	Jetty	t	t	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	tarkwa bay doesnt run like a typical commercial jetty. the people there usually just call back boats that brought them. there are times when there are commercial boats available to take people out to either cms or ferry point but its mostly available at peak hours or round the clock during the festive season.	applied	\N
51	5	2026-02-18 11:27:11.589+00	Apapa Flour Mill	Jetty	t	t	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	The boats to Ikorodu operate only in the morning and evening due to low \npassenger demand from the terminal. Additionally, many passengers are reluctant to provide \ntheir information for the manifest, some passengers use life jackets, and ferries do not \noperate on weekends, leaving only small boats in service. 	applied	\N
6	6	2026-01-13 00:00:00+00	Marina/CMS	Jetty	t	t	Every person is wearing a life jacket	\N	\N	\N	applied	\N
52	130	2026-02-18 12:09:42.713+00	Tarkwa Bay	Landing Point	f	t	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	Majority of the boats at tarkwa bay are privately chartered even though they are commercial boats because of the business type at tarkwa bay. The frequency of boats movements can only be determined by passengers availablity which can't even be guessed again due to the business type at tarkwa bay.	applied	\N
53	11	2026-02-18 12:14:48.822+00	Law School	Ferry Terminal	f	t	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	This facility is strictly private. All of the boats at here are privately chartered.	applied	\N
54	101	2026-02-18 12:52:54.212+00	Mile 2/NIWA	Jetty	t	t	Every person is wearing a life jacket	Israel Ekundayo 	israelekundayo@gmail.com	Owode is the main stop. And it's close to Pashi. People from Pashi come to Owode to board.	applied	\N
55	107	2026-02-18 20:08:51.628+00	Ojo market waterside	Landing Point	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	\N	applied	\N
56	89	2026-02-18 21:21:28.576+00	Iyagbe	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	\N	applied	\N
57	73	2026-02-18 21:45:24.259+00	Ikare palace	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	Ikare Palace is a jetty,about 200m from the landing	applied	\N
58	74	2026-02-18 23:21:02.174+00	Ikare town landing	Landing Point	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	\N	applied	\N
59	67	2026-02-19 10:42:13.973+00	Igbologun (Ojo)	Landing Point	t	t	Only some people are wearing life jackets (not everyone)	Israel Ekundayo	israelekundayo@gmail.com	It should be just Igbologun, not Igbologun (ojo).\nAlso, from Igbologun, the drivers and workers there claim that one can privately charter a boat ride to anywhere that's a "water side" (Liverpool, CMS, Badagry, Ijegun, Igbo Elejo, etc.).	applied	\N
60	101	2026-02-19 13:23:55.74+00	Mile 2/NIWA	Jetty	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	None	applied	\N
61	5	2026-02-20 09:50:27.35+00	Apapa Flour Mill	Jetty	t	t	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	\N	applied	\N
62	60	2026-02-20 10:13:29.046+00	Ibese	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	It is an intermediate stop	applied	\N
63	34	2026-02-20 10:59:34.382+00	Bonny Camp	Jetty	f	f	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	Its in the premises of the nigerian army, so its mostly restricted to the general public. However,if you are coming from tarkwa bay, and bonny camp is a closer stop to where you are headed, i believe you can make a stop there.	applied	\N
64	106	2026-02-20 11:01:57.402+00	Ogogoro Village	Landing Point	f	f	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	Its a landing for the people who live on or around that island. Usually people join boats headed to tarkwa bay and make a stop there. There are no designated boats for that particular location usually.	applied	\N
65	128	2026-02-20 11:02:21.592+00	Store	Landing Point	f	f	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	Its a landing for the people who live on or around that island. Usually people join boats headed to tarkwa bay and make a stop there. There are no designated boats for that particular location usually.	applied	\N
66	100	2026-02-20 11:10:26.665+00	Mikano	Jetty	f	f	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	when i went for data collection last year, mikano was open to the public, but now it is strictly private use	applied	\N
67	44	2026-02-20 11:27:03.388+00	Elegushi	Jetty	t	f	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	it is an intermediate stop, the origin is ijegun egba	applied	\N
68	101	2026-02-20 11:46:06.183+00	Mile 2/NIWA	Jetty	t	t	Every person is wearing a life jacket	Fisayo	fisayo@publictech.studio	\N	applied	\N
69	62	2026-02-20 11:47:04.445+00	Ibeshe Palace	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	ibese palace is an intermediate stop	applied	\N
70	12	2026-02-20 11:55:30.757+00	Alluvia Marine/Afisco	Jetty	f	t	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	Its a facility for charters to beaches and private island. No commercial boat can dock here even.	applied	\N
71	101	2026-02-20 12:03:17.086+00	Mile 2/NIWA	Jetty	t	t	Every person is wearing a life jacket	Fisayo	fisayo@publictech.studio	\N	applied	\N
72	7	2026-02-20 12:10:04.829+00	Addax/Sandfill/Maroko	Jetty	t	t	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	\N	applied	\N
73	36	2026-02-20 12:20:46.336+00	Capital Oil	Jetty	t	t	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	\N	applied	\N
74	36	2026-02-20 12:23:38.977+00	Capital Oil	Jetty	t	t	Every person is wearing a life jacket	Sikigha Charity	isikighacharity@gmail.com	\N	applied	\N
75	120	2026-02-20 21:24:09.432+00	Power line	Landing Point	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	it is an intermediate stop	applied	\N
76	114	2026-02-20 21:24:21.313+00	Olu landing	Landing Point	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	it is an intermediate stop.	applied	\N
77	119	2026-02-20 21:32:29.804+00	Police	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	it is an intermediate stop	applied	\N
78	93	2026-02-20 21:50:33.757+00	Koko beach	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	it is an intermediate stop	applied	\N
79	6	2026-02-20 22:58:01.495+00	Marina/CMS	Ferry Terminal	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	\N	applied	\N
80	101	2026-02-23 09:19:05.675+00	Mile 2/NIWA	Jetty	t	t	Every person is wearing a life jacket	Fisayo	fisayo@publictech.studio	\N	applied	\N
2	2	2026-01-13 00:00:00+00	Five Cowries/Falomo/Ise Water	Terminal	t	t	Every person is wearing a life jacket	Lanre	antholaredo1@gmail.com	\N	applied	\N
8	8	2026-01-13 00:00:00+00	Badore Ferry Terminal	Terminal	t	f	Every person is wearing a life jacket	\N	\N	\N	applied	\N
10	10	2026-01-13 00:00:00+00	Liverpool (Apapa)	Jetty	t	t	Every person is wearing a life jacket	\N	\N	\N	applied	\N
14	14	2026-01-13 00:00:00+00	Offin, Ikorodu	Jetty	t	f	Every person is wearing a life jacket	\N	\N	\N	applied	\N
13	13	2026-01-13 00:00:00+00	Jegba Marina Badagry	\N	t	f	Every person is wearing a life jacket	\N	\N	\N	applied	\N
4	4	2026-01-13 00:00:00+00	Port Novo	\N	t	f	Every person is wearing a life jacket	\N	\N	\N	applied	\N
3	3	2026-01-13 00:00:00+00	Ikorodu/Ipakodo Ferry Terminal	Terminal	t	t	Every person is wearing a life jacket	Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	\N	applied	\N
1	1	2026-01-13 00:00:00+00	Ebute Ero/Elegbata Jetty	Terminal	t	f	Every person is wearing a life jacket	Odusami Sheriff Oluwafemi	odusamioluwafemi@gmail.com	\N	applied	\N
11	11	2026-01-13 00:00:00+00	Law School	Landing	t	f	Every person is wearing a life jacket	\N	\N	\N	applied	\N
5	5	2026-01-13 00:00:00+00	Apapa Flour Mill	Jetty	t	f	Every person is wearing a life jacket	\N	\N	\N	applied	\N
12	12	2026-01-13 00:00:00+00	Alluvia Marine/Afisco	Jetty	t	t	Every person is wearing a life jacket	\N	\N	\N	applied	\N
7	7	2026-01-13 00:00:00+00	Addax/Sandfill/Maroko	Jetty	t	f	Every person is wearing a life jacket	\N	\N	\N	applied	\N
16	7	2026-01-13 00:00:00+00	Addax/Sandfill/Maroko	Jetty	t	f	Every person is wearing a life jacket	\N	\N	\N	applied	\N
15	15	2026-01-13 00:00:00+00	Ibeshe/Thesaurus Ferry Terminal	Terminal	t	t	Every person is wearing a life jacket	\N	\N	\N	applied	\N
9	9	2026-01-13 00:00:00+00	Ebute Ojo/Sifax Ferry Terminal	Terminal	t	f	Every person is wearing a life jacket	\N	\N	\N	applied	\N
81	80	2026-02-24 09:36:59.736+00	Irede	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	\N	applied	\N
82	135	2026-02-24 10:27:00.599+00	Uncle Ben	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	it is an intermediate stop	applied	\N
83	122	2026-02-24 10:52:57.586+00	Salt Beach	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	it is an intermediate stop	applied	\N
84	8	2026-02-25 09:23:46.991+00	Badore Ferry Terminal	Ferry Terminal	t	t	Every person is wearing a life jacket	Mr Haruna Deji	harunadeji05@gmail.com	Charter is only available to the destinations	applied	\N
85	86	2026-02-25 09:24:35.152+00	Itomu Jetty	Jetty	t	t	Every person is wearing a life jacket	Mr Haruna Deji	harunadeji05@gmail.com	Charter is only available to the destinations	applied	\N
86	152	2026-02-25 09:57:53.556+00	Kabiyesi itomu jetty	Landing Point	t	f	No one is wearing a life jacket	Fisayo 	Fisayo@publictech.studio	It's just a route used for crossing. About 30m long	applied	\N
87	46	2026-02-25 12:36:24.241+00	Epe Ayetoro Jetty	Ferry Terminal	t	t	Every person is wearing a life jacket	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com	Charter is to anywhere in Lagos 	applied	\N
88	101	2026-02-25 16:58:07.361+00	Mile 2/NIWA	Jetty	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	None	applied	\N
89	58	2026-02-25 17:58:58.397+00	Gberigbe	Jetty	t	t	Every person is wearing a life jacket	Charity Sikigha	isikighacharity@gmail.com	\N	applied	\N
90	79	2026-02-25 18:30:24.61+00	Imore	Jetty	t	t	Every person is wearing a life jacket	Charity Sikigha	isikighacharity@gmail.com	this jetty is frequently used for accessing beach houses than travelling across lagos.	applied	\N
91	42	2026-02-25 18:38:03.213+00	Egbin	Jetty	t	t	Every person is wearing a life jacket	Charity Sikigha	isikighacharity@gmail.com	\N	applied	\N
92	92	2026-02-25 18:44:56.561+00	Kirikiri	Jetty	t	t	Every person is wearing a life jacket	Charity Sikigha	isikighacharity@gmail.com	\N	applied	\N
93	37	2026-02-25 18:50:45.996+00	Cele	Landing Point	t	f	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	This facility is NOT a route origin. It is mainly used as a charter for moving heavy loads.	applied	\N
94	77	2026-02-26 11:19:07.136+00	Ilashe	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	it is an intermediate stop	applied	\N
95	107	2026-02-27 09:23:22.264+00	Ojo market waterside	Jetty	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	\N	applied	\N
96	59	2026-02-27 10:41:35.149+00	Ibasa	Jetty	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	\N	applied	\N
97	125	2026-02-27 10:42:49.153+00	Second Rainbow Landing	Jetty	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	\N	applied	\N
98	30	2026-02-27 10:43:37.008+00	Baba Shino	Landing Point	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	\N	applied	\N
99	6	2026-02-27 11:24:28.608+00	Marina/CMS	Ferry Terminal	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	\N	applied	\N
100	6	2026-02-27 12:14:22.182+00	Marina/CMS	Jetty	t	t	Every person is wearing a life jacket	Charity Sikigha	isikighacharity@gmail.com	\N	applied	\N
101	35	2026-03-02 10:27:43.081+00	Boundary (Apapa)/Number 3 (Apapa) Waterside	Landing Point	t	f	No one is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
102	16	2026-03-02 10:28:19.043+00	Number 3 (Ajegunle) Waterside	Landing Point	t	f	No one is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
103	149	2026-03-02 10:28:42.843+00	Number 1 (Ajegunle) Waterside	Landing Point	t	f	No one is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
104	151	2026-03-02 10:29:06.188+00	Number 1 (Apapa) Waterside	Landing Point	t	f	No one is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
105	147	2026-03-02 10:29:42.464+00	Number 2 (Ajegunle) Waterside	Landing Point	t	f	No one is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
106	105	2026-03-02 10:30:03.617+00	Number 2 (Apapa) Waterside	Landing Point	t	f	No one is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
107	104	2026-03-02 10:30:57.407+00	Number 1A Waterside	Landing Point	t	f	No one is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
108	124	2026-03-02 10:31:29.214+00	Second Badagry	Landing Point	t	f	No one is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
109	102	2026-03-02 10:31:41.242+00	Mogaji (Ajegunle)	Landing Point	t	f	No one is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
110	91	2026-03-02 10:33:34.574+00	KabaKaba	Landing Point	t	f	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
111	99	2026-03-02 10:34:02.157+00	Manager	Landing Point	t	f	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
112	5	2026-03-02 10:38:09.63+00	Apapa Flour Mill	Jetty	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	You can charter fibre boats here owned by private individuals.	applied	\N
113	55	2026-03-02 10:48:07.761+00	First Gate (Tin Can Island)	Jetty	t	f	Only some people are wearing life jackets (not everyone)	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
114	75	2026-03-02 10:50:05.317+00	IKO/Temidire	Jetty	t	t	Only some people are wearing life jackets (not everyone)	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Next to the jetty are fibres boats you can charter to Ibasa for 20000-30000 naira depending on your luggage.You can't charter boats to First Gate(TinCan Island)	applied	\N
115	24	2026-03-02 11:01:12.759+00	Agojedo/Agbejedo	Landing Point	t	f	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
116	129	2026-03-02 11:26:32.24+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	You can charter boats to Itu-agan or Liverpool here.	applied	\N
117	78	2026-03-02 11:27:35.134+00	Ilutuntun	Landing Point	t	f	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
118	78	2026-03-02 11:27:55.08+00	Ilutuntun	Landing Point	t	f	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
119	64	2026-03-02 11:29:26.557+00	Igbo Elejo	Landing Point	t	f	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	\N	applied	\N
120	84	2026-03-02 11:37:38.931+00	Isoda	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	You can charter boats to Liverpool and Itun-agan.	applied	\N
121	85	2026-03-02 11:40:40.123+00	Itu Agan/Itun Agan	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	You can charter boats to all destination routes here.	applied	\N
162	129	2026-03-05 16:32:39.496+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to liverpool at 50,000 naira	applied	\N
123	57	2026-03-03 09:06:03.718+00	Gbaji Yekeme Jetty	Jetty	t	t	Every person is wearing a life jacket	Officer Samuel 	Samuelolorunwamautin@yahoo.com	Charter is available to those destinations. This isn’t the origin jetty	applied	\N
124	156	2026-03-03 09:06:23.674+00	Farasimeh	Jetty	t	t	Every person is wearing a life jacket	Officer Samuel 	Samuelolorunwamautin@yahoo.com	Charter is available to those destinations. This isn’t the origin jetty	applied	\N
125	88	2026-03-03 09:43:53.599+00	Iya Afin Jetty	Jetty	t	t	Every person is wearing a life jacket	Mr Kazeem	Kazeemfayemi0@gmail.com	Charter is only available to izigi	applied	\N
126	7	2026-03-03 17:48:13.843+00	Addax/Sandfill/Maroko	Jetty	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	\N	applied	\N
122	133	2026-03-02 16:20:38.322+00	Tolu Ajegunle	Jetty	f	f	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	The jetty at the back of the church is used by the church for its own purposes.	applied	\N
127	13	2026-03-04 13:28:34.841+00	Jegba Marina Badagry/Commando Jetty	Jetty	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	\N
128	74	2026-03-04 20:23:13.621+00	Ikare town landing	Landing Point	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	\N	applied	\N
129	89	2026-03-04 20:28:39.109+00	Iyagbe	Jetty	t	t	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	\N	applied	\N
130	90	2026-03-05 02:49:21.116+00	Jemuje	Landing Point	f	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	This facility is for charter only.	applied	\N
131	64	2026-03-05 02:55:06.437+00	Igbo Elejo	Landing Point	t	t	Only some people are wearing life jackets (not everyone)	Israel Ekundayo	israelekundayo@gmail.com	\N	applied	\N
132	78	2026-03-05 03:06:09.902+00	Ilutuntun	Landing Point	t	t	Only some people are wearing life jackets (not everyone)	Israel Ekundayo	israelekundayo@gmail.com	This is not a destination facility. It is an intermediate stop for the route: Liverpool (Apapa) to Isoda	applied	\N
133	64	2026-03-05 03:08:42.494+00	Igbo Elejo	Landing Point	t	t	Only some people are wearing life jackets (not everyone)	Israel Ekundayo	israelekundayo@gmail.com	This facility is an intermediate stop for the route Liverpool (Apapa) to Isoda	applied	\N
134	133	2026-03-05 15:24:54.348+00	Tolu Ajegunle	Jetty	f	f	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	It belongs to an Anglican church. The church uses the jetty for its own purposes.	applied	\N
135	129	2026-03-05 15:28:25.642+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartedted to Liverpool at 50k.	applied	\N
136	129	2026-03-05 15:28:42.101+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered to Liverpool at 50k.	applied	\N
137	129	2026-03-05 15:29:50.779+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered to Liverpool at 50k.	applied	\N
138	129	2026-03-05 15:32:13.27+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
139	129	2026-03-05 15:34:02.592+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
140	129	2026-03-05 15:34:34.111+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
141	129	2026-03-05 15:34:39.485+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
142	129	2026-03-05 15:36:14.234+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
143	129	2026-03-05 15:36:22.302+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
144	129	2026-03-05 15:38:20.066+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
145	129	2026-03-05 15:39:36.026+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
146	129	2026-03-05 15:39:41.445+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
147	129	2026-03-05 15:40:08.936+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
148	129	2026-03-05 15:42:20.506+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
149	129	2026-03-05 15:42:57.676+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
150	129	2026-03-05 15:44:58.149+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
151	129	2026-03-05 15:51:16.462+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
152	129	2026-03-05 16:02:41.838+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
153	129	2026-03-05 16:03:38.295+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
154	129	2026-03-05 16:08:32.086+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
155	129	2026-03-05 16:08:37.86+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
156	129	2026-03-05 16:08:43.322+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
157	129	2026-03-05 16:08:48.062+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
158	129	2026-03-05 16:08:54.575+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
159	129	2026-03-05 16:10:30.526+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
160	129	2026-03-05 16:10:45.431+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
161	129	2026-03-05 16:30:08.307+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats can be chartered at 50k to Liverpool.	applied	\N
163	129	2026-03-05 16:32:46.419+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to liverpool at 50,000 naira	applied	\N
164	129	2026-03-05 16:33:28.678+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira	applied	\N
165	129	2026-03-05 16:41:09.716+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira	applied	\N
166	129	2026-03-05 16:45:17.567+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira	applied	\N
167	129	2026-03-05 17:35:44.27+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira	applied	\N
168	129	2026-03-05 17:54:48.459+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira	applied	\N
169	129	2026-03-05 17:54:55.078+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira	applied	\N
170	129	2026-03-05 17:54:59.875+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira	applied	\N
171	129	2026-03-05 17:57:09.37+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira	applied	\N
172	129	2026-03-05 18:29:27.108+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira	applied	\N
173	129	2026-03-05 18:31:22.909+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira.	applied	\N
174	129	2026-03-05 18:48:45.105+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira.	applied	\N
175	129	2026-03-05 19:22:36.314+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira.	applied	\N
176	129	2026-03-05 22:20:49.175+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered to Liverpool at 50,000 naira.	applied	\N
177	200	2026-03-06 11:37:13.283+00	Badore Ferry Terminal	Ferry Terminal	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	\N
178	200	2026-03-06 11:39:31.075+00	Badore Ferry Terminal	Ferry Terminal	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	\N
179	129	2026-03-06 12:30:16.22+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
180	129	2026-03-06 12:30:18.983+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
181	129	2026-03-06 12:30:21.801+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
182	129	2026-03-06 12:30:31.159+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
183	129	2026-03-06 12:30:33.036+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
184	129	2026-03-06 12:30:35.86+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
185	129	2026-03-06 12:30:40.849+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
186	129	2026-03-06 12:30:50.345+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
187	129	2026-03-06 12:30:52.203+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
188	129	2026-03-06 12:30:55.08+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
189	129	2026-03-06 12:31:00.888+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k to Liverpool	applied	\N
190	129	2026-03-06 12:46:13.583+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k	applied	\N
191	129	2026-03-06 12:46:15.373+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k	applied	\N
192	129	2026-03-06 12:46:18.161+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k	applied	\N
193	129	2026-03-06 12:46:23.05+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50k	applied	\N
194	129	2026-03-06 13:22:43.627+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50,000 naira to Liverpool	applied	\N
195	129	2026-03-06 13:22:45.38+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50,000 naira to Liverpool	applied	\N
196	129	2026-03-06 13:22:48.195+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50,000 naira to Liverpool	applied	\N
197	129	2026-03-06 13:22:53.095+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50,000 naira to Liverpool	applied	\N
198	129	2026-03-06 14:10:17.467+00	Itomoro	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Boats are chartered at 50,000 naira to Liverpool	applied	\N
199	19	2026-03-06 21:09:42.522+00	Agaja	Landing Point	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	None	applied	\N
200	81	2026-03-06 21:10:07.349+00	Irewe Ojo	Landing Point	t	t	Every person is wearing a life jacket	Israel Ekundayo	israelekundayo@gmail.com	None	applied	\N
201	220	2026-03-09 13:32:34.919+00	Alelegbene	Landing Point	t	t	Every person is wearing a life jacket	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	Most chartered destination: Liverpool.	applied	\N
202	100	2026-03-10 09:39:51.223+00	Mikano	Jetty	f	f	Every person is wearing a life jacket	Kokodoko Victor Ayomide	kokosvictorayomide@gmail.com	\N	applied	\N
203	1	2026-03-11 08:44:07.514+00	Ebute Ero/Elegbata Jetty	Jetty	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	Charter is possible to destinations	applied	[{"isCharter": null, "destinationId": 5, "destinationName": "Apapa Flour Mill"}, {"isCharter": null, "destinationId": 6, "destinationName": "Marina/CMS"}, {"isCharter": null, "destinationId": 3, "destinationName": "Ikorodu/Ipakodo Ferry Terminal"}, {"isCharter": null, "destinationId": 4, "destinationName": "Port Novo"}, {"isCharter": null, "destinationId": 13, "destinationName": "Jegba Marina Badagry/Commando Jetty"}]
211	52	2026-03-11 09:19:54.326+00	Ferry Port/Checkpoint	Landing Point	f	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	Charter is possible to anywhere in Lagos	applied	[{"isCharter": true, "destinationId": 130, "destinationName": "Tarkwa Bay"}]
210	22	2026-03-11 09:18:19.422+00	Oko Agbon	Landing Point	t	t	Only some people are wearing life jackets (not everyone)	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 23, "destinationName": "Agboyi Ketu"}, {"isCharter": null, "destinationId": 21, "destinationName": "Agboyi 2"}, {"isCharter": null, "destinationId": 112, "destinationName": "Agboyi 1"}]
209	22	2026-03-11 09:17:57.377+00	Oko Agbon	Landing Point	t	t	Only some people are wearing life jackets (not everyone)	Fisayo Balogun	fisayo@publictech.studio	\N	rejected	[{"isCharter": null, "destinationId": 23, "destinationName": "Agboyi Ketu"}, {"isCharter": null, "destinationId": 21, "destinationName": "Agboyi 2"}, {"isCharter": null, "destinationId": 112, "destinationName": "Agboyi 1"}, {"isCharter": null, "destinationId": 20, "destinationName": "Agboyi 3"}]
208	112	2026-03-11 09:16:57.884+00	Agboyi 1	Landing Point	t	t	Only some people are wearing life jackets (not everyone)	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 23, "destinationName": "Agboyi Ketu"}, {"isCharter": null, "destinationId": 22, "destinationName": "Oko Agbon"}, {"isCharter": null, "destinationId": 21, "destinationName": "Agboyi 2"}]
207	21	2026-03-11 09:16:12.943+00	Agboyi 2	Landing Point	t	f	No one is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 23, "destinationName": "Agboyi Ketu"}, {"isCharter": null, "destinationId": 112, "destinationName": "Agboyi 1"}, {"isCharter": null, "destinationId": 22, "destinationName": "Oko Agbon"}]
206	20	2026-03-11 09:15:11.652+00	Agboyi 3	Landing Point	t	f	No one is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 23, "destinationName": "Agboyi Ketu"}]
205	3	2026-03-11 09:13:39.805+00	Ikorodu/Ipakodo Ferry Terminal	Ferry Terminal	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 7, "destinationName": "Addax/Sandfill/Maroko"}, {"isCharter": null, "destinationId": 6, "destinationName": "Marina/CMS"}, {"isCharter": null, "destinationId": 10, "destinationName": "Liverpool (Apapa)"}, {"isCharter": null, "destinationId": 1, "destinationName": "Ebute Ero/Elegbata Jetty"}, {"isCharter": null, "destinationId": 2, "destinationName": "Five Cowries/Falomo/Ise Water"}, {"isCharter": null, "destinationId": 5, "destinationName": "Apapa Flour Mill"}, {"isCharter": null, "destinationId": 12, "destinationName": "Alluvia Marine/Afisco"}]
204	2	2026-03-11 09:10:27.054+00	Five Cowries/Falomo/Ise Water	Ferry Terminal	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 3, "destinationName": "Ikorodu/Ipakodo Ferry Terminal"}, {"isCharter": null, "destinationId": 14, "destinationName": "Offin, Ikorodu"}, {"isCharter": null, "destinationId": 15, "destinationName": "Ibeshe/Thesaurus Ferry Terminal"}, {"isCharter": null, "destinationId": 7, "destinationName": "Addax/Sandfill/Maroko"}, {"isCharter": null, "destinationId": 200, "destinationName": "Badore Ferry Terminal"}, {"isCharter": null, "destinationId": 6, "destinationName": "Marina/CMS"}, {"isCharter": null, "destinationId": 10, "destinationName": "Liverpool (Apapa)"}]
219	140	2026-03-11 09:42:06.227+00	Ponton	Landing Point	t	f	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 18, "destinationName": "Abule Osun"}, {"isCharter": null, "destinationId": 13, "destinationName": "Jegba Marina Badagry/Commando Jetty"}]
218	139	2026-03-11 09:41:07.719+00	Pashi	Landing Point	t	f	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 101, "destinationName": "Mile 2/NIWA"}, {"isCharter": null, "destinationId": 4, "destinationName": "Port Novo"}, {"isCharter": null, "destinationId": 18, "destinationName": "Abule Osun"}]
217	146	2026-03-11 09:40:28.537+00	Owode	Landing Point	t	f	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 101, "destinationName": "Mile 2/NIWA"}, {"isCharter": null, "destinationId": 4, "destinationName": "Port Novo"}]
216	157	2026-03-11 09:38:51.846+00	Izigi (Ogun)	Landing Point	t	f	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 88, "destinationName": "Iya Afin Jetty"}]
215	154	2026-03-11 09:38:14.529+00	Iwopin (Ogun)	Landing Point	t	f	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 46, "destinationName": "Epe Ayetoro Jetty"}]
214	153	2026-03-11 09:37:59.499+00	Ipare (Ondo)	Landing Point	t	f	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 46, "destinationName": "Epe Ayetoro Jetty"}]
213	144	2026-03-11 09:37:20.794+00	Ijon Odo (Ogun)	Landing Point	t	t	Only some people are wearing life jackets (not everyone)	Fisayo Balogun	fisayo@publictech.studio	Charter is possible to the destination	applied	[{"isCharter": null, "destinationId": 71, "destinationName": "Ijon"}]
212	155	2026-03-11 09:36:41.609+00	Eyin Osa	Landing Point	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	Charter is possible to the destination	applied	[{"isCharter": null, "destinationId": 46, "destinationName": "Epe Ayetoro Jetty"}]
221	4	2026-03-11 09:50:14.646+00	Port Novo	Landing Point	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 1, "destinationName": "Ebute Ero/Elegbata Jetty"}, {"isCharter": null, "destinationId": 13, "destinationName": "Jegba Marina Badagry/Commando Jetty"}, {"isCharter": null, "destinationId": 18, "destinationName": "Abule Osun"}, {"isCharter": null, "destinationId": 139, "destinationName": "Pashi"}, {"isCharter": null, "destinationId": 101, "destinationName": "Mile 2/NIWA"}, {"isCharter": null, "destinationId": 146, "destinationName": "Owode"}, {"isCharter": null, "destinationId": 92, "destinationName": "Kirikiri"}, {"isCharter": null, "destinationId": 6, "destinationName": "Marina/CMS"}, {"isCharter": null, "destinationId": 57, "destinationName": "Gbaji Yekeme Jetty"}, {"isCharter": null, "destinationId": 10, "destinationName": "Liverpool (Apapa)"}]
220	145	2026-03-11 09:43:00.194+00	Totowu Odo (Ogun)	Landing Point	t	t	Only some people are wearing life jackets (not everyone)	Fisayo Balogun	fisayo@publictech.studio	Charter is available only to the destination	applied	[{"isCharter": null, "destinationId": 63, "destinationName": "Igando Landing/Ishitu"}]
222	17	2026-03-11 09:52:21.037+00	Abomiti-Nla Epe	Landing Point	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": null, "destinationId": 46, "destinationName": "Epe Ayetoro Jetty"}]
223	126	2026-03-11 11:58:18.423+00	Slave Route Landing	Landing Point	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": true, "destinationId": 221, "destinationName": "Point of no return"}]
224	221	2026-03-11 11:59:09.509+00	Point of no return	Landing Point	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	\N
225	221	2026-03-11 11:59:22.673+00	Point of no return	Landing Point	t	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	\N
226	100	2026-03-11 13:10:37.229+00	Mikano	Jetty	f	t	Every person is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	\N
227	54	2026-03-24 12:03:40.436+00	Fiki Marine	Jetty	t	t	Every person is wearing a life jacket	Hannah Kates	hannah@publictech.studio	All tickets are round-trip.	applied	[{"isCharter": false, "destinationId": 130, "destinationName": "Tarkwa Bay"}]
228	79	2026-03-25 10:12:02.552+00	Imore Waterside	Jetty	t	t	No one is wearing a life jacket	Fisayo Balogun	fisayo@publictech.studio	\N	applied	[{"isCharter": false, "destinationId": 222, "destinationName": "Imore Community"}, {"isCharter": true, "destinationId": 59, "destinationName": "Ibasa"}]
\.


--
-- Data for Name: feed_info_gtfs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.feed_info_gtfs (generated_at, feed_publisher_name, feed_publisher_url, feed_lang, feed_start_date, feed_end_date, feed_version) FROM stdin;
2026-05-19 14:13:19.872748	Public Tech Studio	https://lagosferries.com/gtfs.zip	en	20260312	20310312	1.2
\.


--
-- Data for Name: frequencies_gtfs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.frequencies_gtfs (generated_at, trip_id, start_time, end_time, headway_secs, exact_times) FROM stdin;
2026-05-19 14:13:19.872748	T4_0_465	17:00:00	18:00:00	3600	0
2026-05-19 14:13:19.872748	T4_1_464	06:30:00	07:30:00	3600	0
2026-05-19 14:13:19.872748	T8_0_462	06:30:00	10:00:00	1800	0
2026-05-19 14:13:19.872748	T8_1_463	16:30:00	18:30:00	1200	0
2026-05-19 14:13:19.872748	T9_0_470	06:30:00	10:00:00	1800	0
2026-05-19 14:13:19.872748	T9_1_471	17:00:00	19:55:00	1500	0
2026-05-19 14:13:19.872748	T10_0_466	07:00:00	07:45:00	2700	0
2026-05-19 14:13:19.872748	T10_1_467	17:30:00	18:15:00	2700	0
2026-05-19 14:13:19.872748	T11_0_476	06:30:00	08:30:00	900	0
2026-05-19 14:13:19.872748	T11_0_474	06:30:00	08:30:00	600	0
2026-05-19 14:13:19.872748	T11_0_480	08:30:00	10:30:00	1200	0
2026-05-19 14:13:19.872748	T11_0_478	08:30:00	11:00:00	1200	0
2026-05-19 14:13:19.872748	T11_0_479	11:00:00	12:00:00	1800	0
2026-05-19 14:13:19.872748	T11_1_475	17:30:00	18:30:00	600	0
2026-05-19 14:13:19.872748	T11_1_477	17:30:00	18:30:00	900	0
2026-05-19 14:13:19.872748	T11_1_481	18:30:00	19:00:00	900	0
2026-05-19 14:13:19.872748	T12_0_25	05:30:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T12_0_27	07:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T12_0_29	09:00:00	14:00:00	1500	0
2026-05-19 14:13:19.872748	T12_0_31	14:00:00	16:00:00	1200	0
2026-05-19 14:13:19.872748	T12_0_33	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T12_0_35	18:00:00	20:00:00	1500	0
2026-05-19 14:13:19.872748	T12_1_26	05:30:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T12_1_28	07:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T12_1_30	09:00:00	14:00:00	1500	0
2026-05-19 14:13:19.872748	T12_1_32	14:00:00	16:00:00	1200	0
2026-05-19 14:13:19.872748	T12_1_34	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T12_1_36	18:00:00	20:00:00	1500	0
2026-05-19 14:13:19.872748	T13_0_37	05:30:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T13_0_39	07:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T13_0_41	09:00:00	14:00:00	1500	0
2026-05-19 14:13:19.872748	T13_0_43	14:00:00	16:00:00	1200	0
2026-05-19 14:13:19.872748	T13_0_45	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T13_0_47	18:00:00	20:00:00	1500	0
2026-05-19 14:13:19.872748	T13_1_38	05:30:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T13_1_40	07:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T13_1_42	09:00:00	14:00:00	1500	0
2026-05-19 14:13:19.872748	T13_1_44	14:00:00	16:00:00	1200	0
2026-05-19 14:13:19.872748	T13_1_46	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T13_1_48	18:00:00	20:00:00	1500	0
2026-05-19 14:13:19.872748	T14_0_49	05:30:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T14_0_51	07:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T14_0_53	09:00:00	14:00:00	1500	0
2026-05-19 14:13:19.872748	T14_0_55	14:00:00	16:00:00	1200	0
2026-05-19 14:13:19.872748	T14_0_57	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T14_1_50	05:30:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T14_1_52	07:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T14_1_54	09:00:00	14:00:00	1500	0
2026-05-19 14:13:19.872748	T14_1_56	14:00:00	16:00:00	1200	0
2026-05-19 14:13:19.872748	T14_1_58	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T16_0_65	04:00:00	07:00:00	1500	0
2026-05-19 14:13:19.872748	T16_0_67	07:00:00	13:00:00	2700	0
2026-05-19 14:13:19.872748	T16_1_66	04:00:00	07:00:00	1500	0
2026-05-19 14:13:19.872748	T16_1_68	07:00:00	13:00:00	2700	0
2026-05-19 14:13:19.872748	T17_0_71	17:00:00	17:45:00	2700	0
2026-05-19 14:13:19.872748	T17_1_70	07:00:00	07:45:00	2700	0
2026-05-19 14:13:19.872748	T19_0_77	06:00:00	10:00:00	3600	0
2026-05-19 14:13:19.872748	T19_1_78	06:00:00	10:00:00	3600	0
2026-05-19 14:13:19.872748	T24_0_102	13:00:00	16:30:00	3600	0
2026-05-19 14:13:19.872748	T24_1_103	13:00:00	16:30:00	3600	0
2026-05-19 14:13:19.872748	T25_0_104	06:30:00	10:00:00	300	0
2026-05-19 14:13:19.872748	T25_0_106	10:00:00	15:01:00	900	0
2026-05-19 14:13:19.872748	T25_0_108	15:01:00	18:00:00	300	0
2026-05-19 14:13:19.872748	T25_1_105	06:30:00	10:00:00	300	0
2026-05-19 14:13:19.872748	T25_1_107	10:00:00	15:01:00	900	0
2026-05-19 14:13:19.872748	T25_1_109	15:01:00	18:00:00	300	0
2026-05-19 14:13:19.872748	T27_0_116	06:00:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T27_0_118	07:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T27_0_120	09:00:00	18:45:00	1500	0
2026-05-19 14:13:19.872748	T27_1_117	06:00:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T27_1_119	07:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T27_1_121	09:00:00	18:45:00	1500	0
2026-05-19 14:13:19.872748	T28_0_122	06:00:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T28_0_124	07:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T28_0_126	09:00:00	18:45:00	1500	0
2026-05-19 14:13:19.872748	T28_1_123	06:00:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T28_1_125	07:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T28_1_127	09:00:00	18:45:00	1500	0
2026-05-19 14:13:19.872748	T29_0_128	06:00:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T29_0_130	07:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T29_0_132	09:00:00	18:45:00	1500	0
2026-05-19 14:13:19.872748	T29_1_129	06:00:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T29_1_131	07:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T29_1_133	09:00:00	18:45:00	1500	0
2026-05-19 14:13:19.872748	T30_0_134	06:00:00	18:00:00	2700	0
2026-05-19 14:13:19.872748	T30_0_136	06:00:00	13:00:00	7200	0
2026-05-19 14:13:19.872748	T30_0_138	13:00:00	17:00:00	2700	0
2026-05-19 14:13:19.872748	T30_1_135	06:00:00	18:00:00	2700	0
2026-05-19 14:13:19.872748	T30_1_137	06:00:00	13:00:00	7200	0
2026-05-19 14:13:19.872748	T30_1_139	13:00:00	17:00:00	2700	0
2026-05-19 14:13:19.872748	T31_0_140	18:00:00	20:00:00	7200	0
2026-05-19 14:13:19.872748	T33_0_142	06:30:00	10:30:00	600	0
2026-05-19 14:13:19.872748	T33_0_144	10:30:00	16:00:00	1800	0
2026-05-19 14:13:19.872748	T33_0_146	16:00:00	18:30:00	600	0
2026-05-19 14:13:19.872748	T33_1_143	06:30:00	10:30:00	600	0
2026-05-19 14:13:19.872748	T33_1_145	10:30:00	16:00:00	1800	0
2026-05-19 14:13:19.872748	T33_1_147	16:00:00	18:30:00	600	0
2026-05-19 14:13:19.872748	T34_0_187	05:30:00	06:20:00	600	0
2026-05-19 14:13:19.872748	T34_0_183	06:30:00	07:20:00	300	0
2026-05-19 14:13:19.872748	T34_0_191	06:30:00	07:00:00	1800	0
2026-05-19 14:13:19.872748	T36_0_193	06:30:00	07:10:00	2400	0
2026-05-19 14:13:19.872748	T36_1_196	16:30:00	17:10:00	2400	0
2026-05-19 14:13:19.872748	T37_0_197	07:00:00	09:15:00	900	0
2026-05-19 14:13:19.872748	T37_1_200	17:00:00	18:30:00	1800	0
2026-05-19 14:13:19.872748	T38_0_201	06:30:00	09:00:00	900	0
2026-05-19 14:13:19.872748	T38_0_203	09:00:00	15:30:00	2100	0
2026-05-19 14:13:19.872748	T38_1_204	09:00:00	15:30:00	2100	0
2026-05-19 14:13:19.872748	T38_1_206	15:30:00	18:30:00	900	0
2026-05-19 14:13:19.872748	T40_0_213	07:00:00	07:30:00	1800	0
2026-05-19 14:13:19.872748	T40_1_216	17:30:00	18:00:00	1800	0
2026-05-19 14:13:19.872748	T41_0_217	06:00:00	11:00:00	1800	0
2026-05-19 14:13:19.872748	T41_0_219	11:00:00	18:00:00	2700	0
2026-05-19 14:13:19.872748	T41_1_218	06:00:00	11:00:00	1800	0
2026-05-19 14:13:19.872748	T41_1_220	11:00:00	18:00:00	2700	0
2026-05-19 14:13:19.872748	T43_0_227	06:00:00	12:00:00	1200	0
2026-05-19 14:13:19.872748	T43_0_229	12:00:00	15:00:00	2400	0
2026-05-19 14:13:19.872748	T43_0_231	15:00:00	18:00:00	1200	0
2026-05-19 14:13:19.872748	T43_1_228	06:00:00	12:00:00	1200	0
2026-05-19 14:13:19.872748	T43_1_230	12:00:00	15:00:00	2400	0
2026-05-19 14:13:19.872748	T43_1_232	15:00:00	18:00:00	1200	0
2026-05-19 14:13:19.872748	T44_0_233	03:00:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T44_0_243	05:30:00	10:00:00	1500	0
2026-05-19 14:13:19.872748	T44_0_235	07:00:00	11:00:00	600	0
2026-05-19 14:13:19.872748	T44_0_245	10:00:00	13:00:00	2100	0
2026-05-19 14:13:19.872748	T44_0_237	11:00:00	16:00:00	1500	0
2026-05-19 14:13:19.872748	T44_0_247	13:00:00	18:00:00	1800	0
2026-05-19 14:13:19.872748	T44_0_239	16:00:00	19:00:00	600	0
2026-05-19 14:13:19.872748	T44_0_241	19:00:00	20:30:00	1800	0
2026-05-19 14:13:19.872748	T44_1_234	03:00:00	07:00:00	1200	0
2026-05-19 14:13:19.872748	T44_1_244	05:30:00	10:00:00	1500	0
2026-05-19 14:13:19.872748	T44_1_236	07:00:00	11:00:00	600	0
2026-05-19 14:13:19.872748	T44_1_246	10:00:00	13:00:00	2100	0
2026-05-19 14:13:19.872748	T44_1_238	11:00:00	16:00:00	1500	0
2026-05-19 14:13:19.872748	T44_1_248	13:00:00	18:00:00	1800	0
2026-05-19 14:13:19.872748	T44_1_240	16:00:00	19:00:00	600	0
2026-05-19 14:13:19.872748	T44_1_242	19:00:00	20:30:00	1800	0
2026-05-19 14:13:19.872748	T45_0_249	06:30:00	18:30:00	14400	0
2026-05-19 14:13:19.872748	T45_1_250	06:30:00	18:30:00	14400	0
2026-05-19 14:13:19.872748	T46_0_251	06:30:00	18:30:00	3600	0
2026-05-19 14:13:19.872748	T46_1_252	06:30:00	18:30:00	3600	0
2026-05-19 14:13:19.872748	T47_0_255	13:00:00	14:40:00	3000	0
2026-05-19 14:13:19.872748	T47_1_254	08:00:00	09:40:00	3000	0
2026-05-19 14:13:19.872748	T48_0_257	06:30:00	20:00:00	1800	0
2026-05-19 14:13:19.872748	T48_0_259	06:30:00	20:00:00	7200	0
2026-05-19 14:13:19.872748	T48_1_258	06:30:00	20:00:00	1800	0
2026-05-19 14:13:19.872748	T48_1_260	06:30:00	20:00:00	7200	0
2026-05-19 14:13:19.872748	T49_0_265	06:30:00	20:00:00	7200	0
2026-05-19 14:13:19.872748	T49_0_261	07:30:00	08:10:00	2400	0
2026-05-19 14:13:19.872748	T49_1_266	06:30:00	20:00:00	7200	0
2026-05-19 14:13:19.872748	T49_1_264	17:00:00	17:40:00	2400	0
2026-05-19 14:13:19.872748	T50_0_267	06:30:00	18:00:00	300	0
2026-05-19 14:13:19.872748	T50_1_268	06:30:00	18:00:00	300	0
2026-05-19 14:13:19.872748	T53_0_277	06:30:00	12:00:00	600	0
2026-05-19 14:13:19.872748	T53_0_279	12:00:00	14:00:00	900	0
2026-05-19 14:13:19.872748	T53_0_281	14:00:00	18:30:00	600	0
2026-05-19 14:13:19.872748	T53_1_278	06:30:00	12:00:00	600	0
2026-05-19 14:13:19.872748	T53_1_280	12:00:00	14:00:00	900	0
2026-05-19 14:13:19.872748	T53_1_282	14:00:00	18:30:00	600	0
2026-05-19 14:13:19.872748	T54_0_283	06:00:00	08:00:00	1200	0
2026-05-19 14:13:19.872748	T54_0_291	06:00:00	08:00:00	1200	0
2026-05-19 14:13:19.872748	T54_0_285	08:00:00	13:00:00	600	0
2026-05-19 14:13:19.872748	T54_0_293	08:00:00	18:00:00	2700	0
2026-05-19 14:13:19.872748	T54_0_287	13:00:00	15:00:00	2700	0
2026-05-19 14:13:19.872748	T54_0_289	15:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T54_1_292	06:00:00	08:00:00	1200	0
2026-05-19 14:13:19.872748	T54_1_284	06:00:00	08:00:00	1200	0
2026-05-19 14:13:19.872748	T54_1_294	08:00:00	18:00:00	2700	0
2026-05-19 14:13:19.872748	T54_1_286	08:00:00	13:00:00	600	0
2026-05-19 14:13:19.872748	T54_1_288	13:00:00	15:00:00	2700	0
2026-05-19 14:13:19.872748	T54_1_290	15:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T63_0_323	06:00:00	08:00:00	600	0
2026-05-19 14:13:19.872748	T63_0_325	08:00:00	10:00:00	1200	0
2026-05-19 14:13:19.872748	T63_0_327	10:00:00	14:00:00	2100	0
2026-05-19 14:13:19.872748	T63_0_329	14:00:00	16:00:00	1200	0
2026-05-19 14:13:19.872748	T63_0_331	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T63_1_324	06:00:00	08:00:00	600	0
2026-05-19 14:13:19.872748	T63_1_326	08:00:00	10:00:00	1200	0
2026-05-19 14:13:19.872748	T63_1_328	10:00:00	14:00:00	2100	0
2026-05-19 14:13:19.872748	T63_1_330	14:00:00	16:00:00	1200	0
2026-05-19 14:13:19.872748	T63_1_332	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T64_0_333	06:30:00	13:00:00	900	0
2026-05-19 14:13:19.872748	T64_0_335	13:00:00	16:00:00	900	0
2026-05-19 14:13:19.872748	T64_0_337	16:00:00	18:00:00	600	0
2026-05-19 14:13:19.872748	T64_1_334	06:30:00	13:00:00	900	0
2026-05-19 14:13:19.872748	T64_1_336	13:00:00	16:00:00	900	0
2026-05-19 14:13:19.872748	T64_1_338	16:00:00	18:00:00	600	0
2026-05-19 14:13:19.872748	T65_0_349	06:00:00	12:00:00	3600	0
2026-05-19 14:13:19.872748	T65_0_339	06:00:00	08:00:00	2100	0
2026-05-19 14:13:19.872748	T65_0_341	08:00:00	12:00:00	3600	0
2026-05-19 14:13:19.872748	T65_0_351	12:00:00	15:00:00	2700	0
2026-05-19 14:13:19.872748	T65_0_343	12:00:00	14:00:00	4500	0
2026-05-19 14:13:19.872748	T65_0_345	14:00:00	17:00:00	1800	0
2026-05-19 14:13:19.872748	T65_0_353	15:00:00	19:00:00	2700	0
2026-05-19 14:13:19.872748	T65_0_347	17:00:00	19:00:00	3600	0
2026-05-19 14:13:19.872748	T65_1_350	06:00:00	12:00:00	3600	0
2026-05-19 14:13:19.872748	T65_1_340	06:00:00	08:00:00	2100	0
2026-05-19 14:13:19.872748	T65_1_342	08:00:00	12:00:00	3600	0
2026-05-19 14:13:19.872748	T65_1_344	12:00:00	14:00:00	4500	0
2026-05-19 14:13:19.872748	T65_1_352	12:00:00	15:00:00	2700	0
2026-05-19 14:13:19.872748	T65_1_346	14:00:00	17:00:00	1800	0
2026-05-19 14:13:19.872748	T65_1_354	15:00:00	19:00:00	2700	0
2026-05-19 14:13:19.872748	T65_1_348	17:00:00	19:00:00	3600	0
2026-05-19 14:13:19.872748	T66_0_355	06:00:00	09:00:00	2700	0
2026-05-19 14:13:19.872748	T66_0_357	09:00:00	12:00:00	4500	0
2026-05-19 14:13:19.872748	T66_0_359	12:00:00	19:00:00	7200	0
2026-05-19 14:13:19.872748	T66_1_356	06:00:00	09:00:00	2700	0
2026-05-19 14:13:19.872748	T66_1_358	09:00:00	12:00:00	4500	0
2026-05-19 14:13:19.872748	T66_1_360	12:00:00	19:00:00	7200	0
2026-05-19 14:13:19.872748	T67_0_361	06:00:00	09:00:00	2700	0
2026-05-19 14:13:19.872748	T67_0_363	09:00:00	12:00:00	3600	0
2026-05-19 14:13:19.872748	T67_0_365	12:00:00	19:00:00	7200	0
2026-05-19 14:13:19.872748	T67_1_362	06:00:00	09:00:00	2700	0
2026-05-19 14:13:19.872748	T67_1_364	09:00:00	12:00:00	3600	0
2026-05-19 14:13:19.872748	T67_1_366	12:00:00	19:00:00	7200	0
2026-05-19 14:13:19.872748	T68_0_367	06:00:00	09:00:00	2700	0
2026-05-19 14:13:19.872748	T68_0_369	09:00:00	12:00:00	3600	0
2026-05-19 14:13:19.872748	T68_0_371	12:00:00	19:00:00	7200	0
2026-05-19 14:13:19.872748	T68_1_368	06:00:00	09:00:00	2700	0
2026-05-19 14:13:19.872748	T68_1_370	09:00:00	12:00:00	3600	0
2026-05-19 14:13:19.872748	T68_1_372	12:00:00	19:00:00	7200	0
2026-05-19 14:13:19.872748	T71_0_376	06:00:00	09:00:00	2100	0
2026-05-19 14:13:19.872748	T71_0_384	06:00:00	13:00:00	7200	0
2026-05-19 14:13:19.872748	T71_0_378	09:00:00	14:00:00	3600	0
2026-05-19 14:13:19.872748	T71_0_386	13:00:00	19:00:00	900	0
2026-05-19 14:13:19.872748	T71_0_380	14:00:00	17:00:00	1800	0
2026-05-19 14:13:19.872748	T71_0_382	17:00:00	19:00:00	3600	0
2026-05-19 14:13:19.872748	T71_1_385	06:00:00	13:00:00	7200	0
2026-05-19 14:13:19.872748	T71_1_377	06:00:00	09:00:00	2100	0
2026-05-19 14:13:19.872748	T71_1_379	09:00:00	14:00:00	3600	0
2026-05-19 14:13:19.872748	T71_1_387	13:00:00	19:00:00	900	0
2026-05-19 14:13:19.872748	T71_1_381	14:00:00	17:00:00	1800	0
2026-05-19 14:13:19.872748	T71_1_383	17:00:00	19:00:00	3600	0
2026-05-19 14:13:19.872748	T72_0_388	08:00:00	10:00:00	2400	0
2026-05-19 14:13:19.872748	T72_0_390	12:00:00	16:00:00	4800	0
2026-05-19 14:13:19.872748	T72_0_392	16:00:00	18:00:00	1200	0
2026-05-19 14:13:19.872748	T72_1_389	08:00:00	10:00:00	2400	0
2026-05-19 14:13:19.872748	T72_1_391	12:00:00	16:00:00	4800	0
2026-05-19 14:13:19.872748	T72_1_393	16:00:00	18:00:00	1200	0
2026-05-19 14:13:19.872748	T73_0_918	17:30:00	18:40:00	2100	0
2026-05-19 14:13:19.872748	T73_1_917	06:30:00	07:40:00	2100	0
2026-05-19 14:13:19.872748	T74_0_920	17:30:00	18:00:00	1800	0
2026-05-19 14:13:19.872748	T74_1_919	06:30:00	07:00:00	1800	0
2026-05-19 14:13:19.872748	T75_0_406	08:00:00	10:00:00	2400	0
2026-05-19 14:13:19.872748	T75_0_408	12:00:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T75_0_410	16:00:00	18:00:00	3600	0
2026-05-19 14:13:19.872748	T75_1_407	08:00:00	10:00:00	2400	0
2026-05-19 14:13:19.872748	T75_1_409	12:00:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T75_1_411	16:00:00	18:00:00	3600	0
2026-05-19 14:13:19.872748	T76_0_654	06:30:00	07:00:00	1800	0
2026-05-19 14:13:19.872748	T76_0_656	07:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T76_0_658	09:00:00	17:00:00	1800	0
2026-05-19 14:13:19.872748	T76_0_660	17:00:00	18:30:00	600	0
2026-05-19 14:13:19.872748	T76_1_655	06:30:00	07:00:00	1800	0
2026-05-19 14:13:19.872748	T76_1_657	07:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T76_1_659	09:00:00	17:00:00	1800	0
2026-05-19 14:13:19.872748	T76_1_661	17:00:00	18:30:00	600	0
2026-05-19 14:13:19.872748	T77_0_418	06:00:00	10:00:00	1800	0
2026-05-19 14:13:19.872748	T77_0_420	10:00:00	16:00:00	2400	0
2026-05-19 14:13:19.872748	T77_0_422	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T77_1_419	06:00:00	10:00:00	1800	0
2026-05-19 14:13:19.872748	T77_1_421	10:00:00	16:00:00	2400	0
2026-05-19 14:13:19.872748	T77_1_423	16:00:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T89_0_483	17:30:00	17:50:00	1200	0
2026-05-19 14:13:19.872748	T89_1_482	06:30:00	06:50:00	1200	0
2026-05-19 14:13:19.872748	T90_0_484	07:00:00	08:00:00	1800	0
2026-05-19 14:13:19.872748	T90_1_485	17:30:00	17:50:00	1200	0
2026-05-19 14:13:19.872748	T91_0_487	17:30:00	18:00:00	1800	0
2026-05-19 14:13:19.872748	T91_1_486	06:30:00	07:00:00	1800	0
2026-05-19 14:13:19.872748	T92_0_488	06:30:00	18:30:00	1500	0
2026-05-19 14:13:19.872748	T92_1_489	06:30:00	18:30:00	1500	0
2026-05-19 14:13:19.872748	T94_0_492	06:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T94_1_493	06:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T95_0_494	12:00:00	14:00:00	7200	0
2026-05-19 14:13:19.872748	T96_0_495	16:30:00	18:30:00	7200	0
2026-05-19 14:13:19.872748	T97_0_496	13:30:00	15:30:00	7200	0
2026-05-19 14:13:19.872748	T98_0_497	08:00:00	11:00:00	2700	0
2026-05-19 14:13:19.872748	T98_0_499	11:00:00	18:00:00	7200	0
2026-05-19 14:13:19.872748	T98_1_498	08:00:00	11:00:00	2700	0
2026-05-19 14:13:19.872748	T98_1_500	11:00:00	18:00:00	7200	0
2026-05-19 14:13:19.872748	T103_0_509	06:30:00	08:00:00	2700	0
2026-05-19 14:13:19.872748	T107_0_513	07:00:00	07:40:00	1200	0
2026-05-19 14:13:19.872748	T108_0_519	06:30:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T108_0_521	10:30:00	15:30:00	7200	0
2026-05-19 14:13:19.872748	T108_1_520	06:30:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T108_1_522	10:30:00	15:30:00	7200	0
2026-05-19 14:13:19.872748	T108_1_523	15:30:00	18:30:00	1200	0
2026-05-19 14:13:19.872748	T109_0_524	06:30:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T109_0_526	10:30:00	15:30:00	7200	0
2026-05-19 14:13:19.872748	T109_1_525	06:30:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T109_1_527	10:30:00	15:30:00	7200	0
2026-05-19 14:13:19.872748	T109_1_528	15:30:00	18:30:00	1200	0
2026-05-19 14:13:19.872748	T111_0_530	07:00:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T111_0_532	10:30:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T111_0_534	16:00:00	19:00:00	1800	0
2026-05-19 14:13:19.872748	T111_1_531	07:00:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T111_1_533	10:30:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T111_1_535	16:00:00	19:00:00	1800	0
2026-05-19 14:13:19.872748	T112_0_536	08:00:00	19:00:00	10800	0
2026-05-19 14:13:19.872748	T112_1_537	08:00:00	19:00:00	10800	0
2026-05-19 14:13:19.872748	T113_0_538	07:00:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T113_0_540	10:30:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T113_0_542	16:00:00	19:00:00	1800	0
2026-05-19 14:13:19.872748	T113_1_539	07:00:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T113_1_541	10:30:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T113_1_543	16:00:00	19:00:00	1800	0
2026-05-19 14:13:19.872748	T115_0_552	07:00:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T115_0_554	10:30:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T115_0_556	16:00:00	19:00:00	1800	0
2026-05-19 14:13:19.872748	T115_0_558	19:00:00	21:00:00	3600	0
2026-05-19 14:13:19.872748	T115_1_553	07:00:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T115_1_555	10:30:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T115_1_557	16:00:00	19:00:00	1800	0
2026-05-19 14:13:19.872748	T115_1_559	19:00:00	21:00:00	3600	0
2026-05-19 14:13:19.872748	T116_0_560	06:30:00	17:30:00	7200	0
2026-05-19 14:13:19.872748	T116_1_561	06:30:00	17:30:00	7200	0
2026-05-19 14:13:19.872748	T121_0_592	06:30:00	10:00:00	1800	0
2026-05-19 14:13:19.872748	T121_0_594	10:00:00	16:00:00	4500	0
2026-05-19 14:13:19.872748	T121_0_596	16:00:00	17:30:00	1500	0
2026-05-19 14:13:19.872748	T121_1_593	06:30:00	10:00:00	1800	0
2026-05-19 14:13:19.872748	T121_1_595	10:00:00	16:00:00	4500	0
2026-05-19 14:13:19.872748	T121_1_597	16:00:00	17:30:00	1500	0
2026-05-19 14:13:19.872748	T122_0_604	06:30:00	10:00:00	2400	0
2026-05-19 14:13:19.872748	T122_0_606	10:00:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T122_0_608	16:00:00	18:30:00	1800	0
2026-05-19 14:13:19.872748	T122_1_605	06:30:00	10:00:00	2400	0
2026-05-19 14:13:19.872748	T122_1_607	10:00:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T122_1_609	16:00:00	18:30:00	1800	0
2026-05-19 14:13:19.872748	T123_0_610	07:00:00	10:00:00	1200	0
2026-05-19 14:13:19.872748	T123_0_612	10:00:00	16:00:00	3600	0
2026-05-19 14:13:19.872748	T123_0_614	16:00:00	18:30:00	1200	0
2026-05-19 14:13:19.872748	T123_1_611	07:00:00	10:00:00	1200	0
2026-05-19 14:13:19.872748	T123_1_613	10:00:00	16:00:00	3600	0
2026-05-19 14:13:19.872748	T123_1_615	16:00:00	18:30:00	1200	0
2026-05-19 14:13:19.872748	T124_0_616	07:00:00	10:00:00	900	0
2026-05-19 14:13:19.872748	T124_0_618	10:00:00	16:00:00	2700	0
2026-05-19 14:13:19.872748	T124_0_620	16:00:00	18:30:00	900	0
2026-05-19 14:13:19.872748	T124_1_617	07:00:00	10:00:00	900	0
2026-05-19 14:13:19.872748	T124_1_619	10:00:00	16:00:00	2700	0
2026-05-19 14:13:19.872748	T124_1_621	16:00:00	18:30:00	900	0
2026-05-19 14:13:19.872748	T125_0_622	07:00:00	10:00:00	2400	0
2026-05-19 14:13:19.872748	T125_0_624	10:00:00	16:00:00	1800	0
2026-05-19 14:13:19.872748	T125_0_626	16:00:00	18:00:00	600	0
2026-05-19 14:13:19.872748	T125_1_623	07:00:00	10:00:00	2400	0
2026-05-19 14:13:19.872748	T125_1_625	10:00:00	16:00:00	1800	0
2026-05-19 14:13:19.872748	T125_1_627	16:00:00	18:00:00	600	0
2026-05-19 14:13:19.872748	T126_0_806	06:00:00	12:00:00	10800	0
2026-05-19 14:13:19.872748	T128_0_632	06:30:00	18:00:00	2400	0
2026-05-19 14:13:19.872748	T128_1_633	06:30:00	18:00:00	2400	0
2026-05-19 14:13:19.872748	T129_0_827	07:00:00	10:30:00	600	0
2026-05-19 14:13:19.872748	T129_0_829	10:30:00	17:00:00	7200	0
2026-05-19 14:13:19.872748	T129_0_831	17:00:00	22:00:00	1800	0
2026-05-19 14:13:19.872748	T129_1_828	07:00:00	10:30:00	600	0
2026-05-19 14:13:19.872748	T129_1_830	10:30:00	17:00:00	7200	0
2026-05-19 14:13:19.872748	T129_1_832	17:00:00	22:00:00	1800	0
2026-05-19 14:13:19.872748	T131_0_638	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T131_0_640	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T131_0_642	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T131_0_644	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T131_1_639	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T131_1_641	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T131_1_643	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T131_1_645	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T132_0_646	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T132_0_648	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T132_0_650	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T132_0_652	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T132_1_647	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T132_1_649	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T132_1_651	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T132_1_653	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T135_0_678	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T135_0_680	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T135_0_682	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T135_0_684	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T135_1_679	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T135_1_681	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T135_1_683	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T135_1_685	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T136_0_686	07:00:00	09:00:00	3600	0
2026-05-19 14:13:19.872748	T136_1_687	07:00:00	09:00:00	3600	0
2026-05-19 14:13:19.872748	T138_0_696	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T138_0_698	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T138_0_700	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T138_0_702	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T138_1_697	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T138_1_699	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T138_1_701	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T138_1_703	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T140_0_720	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T140_0_712	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T140_0_714	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T140_0_722	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T140_0_716	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T140_0_724	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T140_0_726	19:00:00	21:00:00	600	0
2026-05-19 14:13:19.872748	T140_0_718	19:00:00	22:00:00	600	0
2026-05-19 14:13:19.872748	T140_1_721	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T140_1_713	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T140_1_723	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T140_1_715	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T140_1_717	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T140_1_725	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T140_1_727	19:00:00	21:00:00	600	0
2026-05-19 14:13:19.872748	T140_1_719	19:00:00	22:00:00	600	0
2026-05-19 14:13:19.872748	T142_0_769	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T142_0_771	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T142_0_773	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T142_0_775	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T142_1_770	05:00:00	09:00:00	300	0
2026-05-19 14:13:19.872748	T142_1_772	09:00:00	17:00:00	600	0
2026-05-19 14:13:19.872748	T142_1_774	17:00:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T142_1_776	19:00:00	22:15:00	600	0
2026-05-19 14:13:19.872748	T144_0_760	06:00:00	12:00:00	10800	0
2026-05-19 14:13:19.872748	T148_0_801	06:00:00	15:00:00	7200	0
2026-05-19 14:13:19.872748	T149_0_802	06:00:00	22:00:00	300	0
2026-05-19 14:13:19.872748	T149_1_803	06:00:00	22:00:00	300	0
2026-05-19 14:13:19.872748	T154_0_833	07:00:00	18:30:00	2700	0
2026-05-19 14:13:19.872748	T155_0_835	06:30:00	10:30:00	7200	0
2026-05-19 14:13:19.872748	T156_0_836	07:30:00	12:00:00	5400	0
2026-05-19 14:13:19.872748	T157_0_837	07:30:00	12:00:00	5400	0
2026-05-19 14:13:19.872748	T158_0_838	07:00:00	19:30:00	7200	0
2026-05-19 14:13:19.872748	T158_1_839	07:00:00	19:30:00	7200	0
2026-05-19 14:13:19.872748	T159_0_922	17:30:00	17:55:00	1500	0
2026-05-19 14:13:19.872748	T159_1_921	06:30:00	06:55:00	1500	0
2026-05-19 14:13:19.872748	T160_0_924	17:30:00	17:55:00	1500	0
2026-05-19 14:13:19.872748	T160_1_923	06:30:00	06:55:00	1500	0
2026-05-19 14:13:19.872748	T161_0_926	17:30:00	18:05:00	2100	0
2026-05-19 14:13:19.872748	T161_1_925	06:30:00	07:05:00	2100	0
2026-05-19 14:13:19.872748	T162_0_860	06:00:00	11:00:00	300	0
2026-05-19 14:13:19.872748	T162_0_862	11:00:00	15:30:00	900	0
2026-05-19 14:13:19.872748	T162_0_864	15:30:00	19:00:00	600	0
2026-05-19 14:13:19.872748	T162_1_861	06:00:00	11:00:00	300	0
2026-05-19 14:13:19.872748	T162_1_863	11:00:00	15:30:00	900	0
2026-05-19 14:13:19.872748	T162_1_865	15:30:00	19:00:00	600	0
2026-05-19 14:13:19.872748	T163_0_866	06:00:00	11:00:00	300	0
2026-05-19 14:13:19.872748	T163_0_868	11:00:00	15:30:00	600	0
2026-05-19 14:13:19.872748	T163_0_870	15:30:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T163_1_867	06:00:00	11:00:00	300	0
2026-05-19 14:13:19.872748	T163_1_869	11:00:00	15:30:00	600	0
2026-05-19 14:13:19.872748	T163_1_871	15:30:00	19:00:00	300	0
2026-05-19 14:13:19.872748	T164_0_872	06:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T164_0_874	09:00:00	13:00:00	1200	0
2026-05-19 14:13:19.872748	T164_0_876	13:00:00	19:00:00	600	0
2026-05-19 14:13:19.872748	T164_0_878	19:00:00	22:00:00	1200	0
2026-05-19 14:13:19.872748	T164_1_873	06:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T164_1_875	09:00:00	13:00:00	1200	0
2026-05-19 14:13:19.872748	T164_1_877	13:00:00	19:00:00	600	0
2026-05-19 14:13:19.872748	T164_1_879	19:00:00	22:00:00	1200	0
2026-05-19 14:13:19.872748	T165_0_880	06:00:00	22:00:00	300	0
2026-05-19 14:13:19.872748	T165_1_881	06:00:00	22:00:00	300	0
2026-05-19 14:13:19.872748	T166_0_882	06:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T166_0_884	09:00:00	13:00:00	1800	0
2026-05-19 14:13:19.872748	T166_0_886	13:00:00	19:00:00	600	0
2026-05-19 14:13:19.872748	T166_0_888	19:00:00	22:00:00	1800	0
2026-05-19 14:13:19.872748	T166_1_883	06:00:00	09:00:00	600	0
2026-05-19 14:13:19.872748	T166_1_885	09:00:00	13:00:00	1800	0
2026-05-19 14:13:19.872748	T166_1_887	13:00:00	19:00:00	600	0
2026-05-19 14:13:19.872748	T166_1_889	19:00:00	22:00:00	1800	0
2026-05-19 14:13:19.872748	T168_0_894	07:00:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T168_0_896	10:30:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T168_1_895	07:00:00	10:30:00	1800	0
2026-05-19 14:13:19.872748	T168_1_897	10:30:00	16:00:00	7200	0
2026-05-19 14:13:19.872748	T170_0_906	11:00:00	17:00:00	3600	0
2026-05-19 14:13:19.872748	T179_0_898	06:30:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T179_1_899	06:30:00	18:00:00	900	0
2026-05-19 14:13:19.872748	T180_0_900	06:30:00	12:00:00	1500	0
2026-05-19 14:13:19.872748	T180_0_901	12:30:00	14:30:00	900	0
2026-05-19 14:13:19.872748	T180_0_902	14:30:00	18:30:00	1500	0
2026-05-19 14:13:19.872748	T180_1_903	06:30:00	12:00:00	1500	0
2026-05-19 14:13:19.872748	T180_1_904	12:30:00	14:30:00	900	0
2026-05-19 14:13:19.872748	T180_1_905	14:30:00	18:30:00	1500	0
2026-05-19 14:13:19.872748	T181_0_907	06:00:00	10:00:00	1200	0
2026-05-19 14:13:19.872748	T181_0_909	10:00:00	14:00:00	2100	0
2026-05-19 14:13:19.872748	T181_0_913	14:00:00	16:00:00	1500	0
2026-05-19 14:13:19.872748	T181_0_915	16:00:00	18:00:00	1200	0
2026-05-19 14:13:19.872748	T181_1_908	06:00:00	10:00:00	1200	0
2026-05-19 14:13:19.872748	T181_1_910	10:00:00	14:00:00	2100	0
2026-05-19 14:13:19.872748	T181_1_914	14:00:00	16:00:00	1500	0
2026-05-19 14:13:19.872748	T181_1_916	16:00:00	18:00:00	1200	0
\.


--
-- Data for Name: route_periods; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.route_periods (route_period_id, route_id, direction_id, morning_service, evening_service, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_time, end_time, single_daily_departure, average_daily_boat_departures, frequency) FROM stdin;
13	1	0	f	t	t	t	t	t	t	f	f	16:15:00	17:00:00	t	1	45
530	111	0	t	f	t	t	t	t	t	t	f	07:00:00	10:30:00	f	\N	30
871	163	1	f	t	t	t	t	t	t	t	f	15:30:00	19:00:00	f	\N	5
870	163	0	f	t	t	t	t	t	t	t	f	15:30:00	19:00:00	f	\N	5
268	50	1	t	t	t	t	t	t	t	t	f	06:30:00	18:00:00	f	\N	5
898	179	0	t	t	t	t	t	t	t	t	t	06:30:00	18:00:00	t	\N	15
900	180	0	t	t	t	t	t	t	t	t	t	06:30:00	12:00:00	t	\N	25
277	53	0	t	t	t	t	t	t	t	t	f	06:30:00	12:00:00	f	\N	10
278	53	1	t	t	t	t	t	t	t	t	f	06:30:00	12:00:00	f	\N	10
29	12	0	t	t	t	t	t	t	t	t	t	09:00:00	14:00:00	f	\N	25
30	12	1	t	t	t	t	t	t	t	t	t	09:00:00	14:00:00	f	\N	25
594	121	0	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	75
595	121	1	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	75
606	122	0	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	120
607	122	1	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	120
616	124	0	t	f	t	t	t	t	t	t	f	07:00:00	10:00:00	f	\N	15
617	124	1	t	f	t	t	t	t	t	t	f	07:00:00	10:00:00	f	\N	15
640	131	0	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	10
641	131	1	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	10
644	131	0	f	t	t	t	t	t	t	t	f	19:00:00	22:15:00	f	\N	10
645	131	1	f	t	t	t	t	t	t	t	f	19:00:00	22:15:00	f	\N	10
648	132	0	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	10
649	132	1	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	10
652	132	0	f	t	t	t	t	t	t	t	f	19:00:00	22:15:00	f	\N	10
653	132	1	f	t	t	t	t	t	t	t	f	19:00:00	22:15:00	f	\N	10
41	13	0	t	t	t	t	t	t	t	t	t	09:00:00	14:00:00	f	\N	25
42	13	1	t	t	t	t	t	t	t	t	t	09:00:00	14:00:00	f	\N	25
54	14	1	t	t	t	t	t	t	t	t	t	09:00:00	14:00:00	f	\N	25
53	14	0	t	t	t	t	t	t	t	t	t	09:00:00	14:00:00	f	\N	25
907	181	0	t	f	t	t	t	t	t	t	f	06:00:00	10:00:00	f	\N	20
908	181	1	t	f	t	t	t	t	t	t	f	06:00:00	10:00:00	f	\N	20
913	181	0	f	t	t	t	t	t	t	t	f	14:00:00	16:00:00	f	\N	25
914	181	1	f	t	t	t	t	t	t	t	f	14:00:00	16:00:00	f	\N	25
915	181	0	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	20
916	181	1	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	20
509	103	0	t	f	t	t	t	t	t	t	f	06:30:00	08:00:00	t	2	45
917	73	1	t	f	t	t	t	t	t	t	f	06:30:00	07:40:00	t	2	35
918	73	0	f	t	t	t	t	t	t	t	f	17:30:00	18:40:00	t	2	35
919	74	1	t	f	t	t	t	t	t	t	f	06:30:00	07:00:00	t	1	30
920	74	0	f	t	t	t	t	t	t	t	f	17:30:00	18:00:00	t	1	30
921	159	1	t	f	t	t	t	t	t	t	f	06:30:00	06:55:00	t	1	25
922	159	0	f	t	t	t	t	t	t	t	f	17:30:00	17:55:00	t	1	25
923	160	1	t	f	t	t	t	t	t	t	f	06:30:00	06:55:00	t	1	25
924	160	0	f	t	t	t	t	t	t	t	f	17:30:00	17:55:00	t	1	25
925	161	1	t	f	t	t	t	t	t	t	f	06:30:00	07:05:00	t	1	35
926	161	0	f	t	t	t	t	t	t	t	f	17:30:00	18:05:00	t	1	35
26	12	1	t	f	t	t	t	t	t	t	t	05:30:00	07:00:00	f	\N	20
35	12	0	f	t	t	t	t	t	t	t	t	18:00:00	20:00:00	f	\N	25
331	63	0	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	15
332	63	1	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	15
36	12	1	f	t	t	t	t	t	t	t	t	18:00:00	20:00:00	f	\N	25
33	12	0	f	t	t	t	t	t	t	t	t	16:00:00	18:00:00	f	\N	15
25	12	0	t	f	t	t	t	t	t	t	t	05:30:00	07:00:00	f	\N	20
34	12	1	f	t	t	t	t	t	t	t	t	16:00:00	18:00:00	f	\N	15
47	13	0	f	t	t	t	t	t	t	t	t	18:00:00	20:00:00	f	\N	25
102	24	0	f	t	f	f	f	f	f	t	t	13:00:00	16:30:00	f	\N	60
103	24	1	f	t	f	f	f	f	f	t	t	13:00:00	16:30:00	f	\N	60
45	13	0	f	t	t	t	t	t	t	t	t	16:00:00	18:00:00	f	\N	15
899	179	1	t	t	t	t	t	t	t	t	t	06:30:00	18:00:00	t	\N	15
894	168	0	t	f	t	t	t	t	t	t	f	07:00:00	10:30:00	f	\N	30
141	32	0	f	t	t	t	t	t	t	t	f	18:00:00	19:40:00	t	1	100
897	168	1	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	120
140	31	0	f	t	t	t	t	t	t	t	f	18:00:00	20:00:00	t	1	120
193	36	0	t	f	t	t	t	t	t	f	f	06:30:00	07:10:00	t	1	40
196	36	1	f	t	t	t	t	t	t	f	f	16:30:00	17:10:00	t	1	40
134	30	0	t	t	t	t	t	t	t	f	f	06:00:00	18:00:00	f	\N	45
135	30	1	t	t	t	t	t	t	t	f	f	06:00:00	18:00:00	f	\N	45
136	30	0	t	t	f	f	f	f	f	t	f	06:00:00	13:00:00	f	\N	120
137	30	1	t	t	f	f	f	f	f	t	f	06:00:00	13:00:00	f	\N	120
261	49	0	t	f	t	t	t	t	t	f	f	07:30:00	08:10:00	t	1	40
264	49	1	f	t	t	t	t	t	t	f	f	17:00:00	17:40:00	t	1	40
191	34	0	t	f	f	f	f	f	f	t	f	06:30:00	07:00:00	f	\N	30
183	34	0	t	f	t	t	t	t	t	f	f	06:30:00	07:20:00	t	10	5
197	37	0	t	f	t	t	t	t	t	f	f	07:00:00	09:15:00	t	9	15
200	37	1	f	t	t	t	t	t	t	f	f	17:00:00	18:30:00	t	3	30
187	34	0	t	f	t	t	t	t	t	f	f	05:30:00	06:20:00	t	11	10
38	13	1	t	f	t	t	t	t	t	t	t	05:30:00	07:00:00	f	\N	20
48	13	1	f	t	t	t	t	t	t	t	t	18:00:00	20:00:00	f	\N	25
46	13	1	f	t	t	t	t	t	t	t	t	16:00:00	18:00:00	f	\N	15
37	13	0	t	f	t	t	t	t	t	t	t	05:30:00	07:00:00	f	\N	20
58	14	1	f	t	t	t	t	t	t	t	t	16:00:00	18:00:00	f	\N	15
57	14	0	f	t	t	t	t	t	t	t	t	16:00:00	18:00:00	f	\N	15
49	14	0	t	f	t	t	t	t	t	t	t	05:30:00	07:00:00	f	\N	20
50	14	1	t	f	t	t	t	t	t	t	t	05:30:00	07:00:00	f	\N	20
909	181	0	t	t	t	t	t	t	t	t	f	10:00:00	14:00:00	f	\N	35
910	181	1	t	t	t	t	t	t	t	t	f	10:00:00	14:00:00	f	\N	35
901	180	0	f	t	t	t	t	t	t	t	t	12:30:00	14:30:00	t	\N	15
138	30	0	f	t	f	f	f	f	f	t	f	13:00:00	17:00:00	f	\N	45
139	30	1	f	t	f	f	f	f	f	t	f	13:00:00	17:00:00	f	\N	45
233	44	0	t	f	t	t	t	t	t	f	f	03:00:00	07:00:00	f	\N	20
237	44	0	t	t	t	t	t	t	t	f	f	11:00:00	16:00:00	f	\N	25
238	44	1	t	t	t	t	t	t	t	f	f	11:00:00	16:00:00	f	\N	25
245	44	0	t	t	f	f	f	f	f	t	f	10:00:00	13:00:00	f	\N	35
246	44	1	t	t	f	f	f	f	f	t	f	10:00:00	13:00:00	f	\N	35
234	44	1	t	f	t	t	t	t	t	f	f	03:00:00	07:00:00	f	\N	20
235	44	0	t	f	t	t	t	t	t	f	f	07:00:00	11:00:00	f	\N	10
236	44	1	t	f	t	t	t	t	t	f	f	07:00:00	11:00:00	f	\N	10
239	44	0	f	t	t	t	t	t	t	f	f	16:00:00	19:00:00	f	\N	10
240	44	1	f	t	t	t	t	t	t	f	f	16:00:00	19:00:00	f	\N	10
241	44	0	f	t	t	t	t	t	t	f	f	19:00:00	20:30:00	f	\N	30
257	48	0	t	t	t	t	t	t	t	f	f	06:30:00	20:00:00	f	\N	30
258	48	1	t	t	t	t	t	t	t	f	f	06:30:00	20:00:00	f	\N	30
259	48	0	t	t	f	f	f	f	f	t	f	06:30:00	20:00:00	f	\N	120
260	48	1	t	t	f	f	f	f	f	t	f	06:30:00	20:00:00	f	\N	120
265	49	0	t	t	f	f	f	f	f	t	f	06:30:00	20:00:00	f	\N	120
266	49	1	t	t	f	f	f	f	f	t	f	06:30:00	20:00:00	f	\N	120
242	44	1	f	t	t	t	t	t	t	f	f	19:00:00	20:30:00	f	\N	30
243	44	0	t	f	f	f	f	f	f	t	f	05:30:00	10:00:00	f	\N	25
244	44	1	t	f	f	f	f	f	f	t	f	05:30:00	10:00:00	f	\N	25
247	44	0	f	t	f	f	f	f	f	t	f	13:00:00	18:00:00	f	\N	30
248	44	1	f	t	f	f	f	f	f	t	f	13:00:00	18:00:00	f	\N	30
118	27	0	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	f	\N	10
119	27	1	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	f	\N	10
122	28	0	t	f	t	t	t	t	t	t	f	06:00:00	07:00:00	f	\N	20
123	28	1	t	f	t	t	t	t	t	t	f	06:00:00	07:00:00	f	\N	20
124	28	0	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	f	\N	10
125	28	1	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	f	\N	10
865	162	1	f	t	t	t	t	t	t	t	f	15:30:00	19:00:00	f	\N	10
128	29	0	t	f	t	t	t	t	t	t	f	06:00:00	07:00:00	f	\N	20
129	29	1	t	f	t	t	t	t	t	t	f	06:00:00	07:00:00	f	\N	20
130	29	0	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	f	\N	10
131	29	1	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	f	\N	10
902	180	0	f	t	t	t	t	t	t	t	t	14:30:00	18:30:00	t	\N	25
289	54	0	f	t	t	t	t	t	t	f	f	15:00:00	18:00:00	f	\N	15
290	54	1	f	t	t	t	t	t	t	f	f	15:00:00	18:00:00	f	\N	15
283	54	0	t	f	t	t	t	t	t	f	f	06:00:00	08:00:00	f	\N	20
284	54	1	t	f	t	t	t	t	t	f	f	06:00:00	08:00:00	f	\N	20
287	54	0	f	t	t	t	t	t	t	f	f	13:00:00	15:00:00	f	\N	45
285	54	0	t	t	t	t	t	t	t	f	f	08:00:00	13:00:00	f	\N	10
286	54	1	t	t	t	t	t	t	t	f	f	08:00:00	13:00:00	f	\N	10
293	54	0	t	t	f	f	f	f	f	t	f	08:00:00	18:00:00	f	\N	45
294	54	1	t	t	f	f	f	f	f	t	f	08:00:00	18:00:00	f	\N	45
288	54	1	f	t	t	t	t	t	t	f	f	13:00:00	15:00:00	f	\N	45
291	54	0	t	f	f	f	f	f	f	t	f	06:00:00	08:00:00	f	\N	20
292	54	1	t	f	f	f	f	f	f	t	f	06:00:00	08:00:00	f	\N	20
339	65	0	t	f	t	t	t	t	t	f	f	06:00:00	08:00:00	f	\N	35
340	65	1	t	f	t	t	t	t	t	f	f	06:00:00	08:00:00	f	\N	35
343	65	0	f	t	t	t	t	t	t	f	f	12:00:00	14:00:00	f	\N	75
344	65	1	f	t	t	t	t	t	t	f	f	12:00:00	14:00:00	f	\N	75
345	65	0	f	t	t	t	t	t	t	f	f	14:00:00	17:00:00	f	\N	30
346	65	1	f	t	t	t	t	t	t	f	f	14:00:00	17:00:00	f	\N	30
347	65	0	f	t	t	t	t	t	t	f	f	17:00:00	19:00:00	f	\N	60
348	65	1	f	t	t	t	t	t	t	f	f	17:00:00	19:00:00	f	\N	60
349	65	0	t	t	f	f	f	f	f	t	f	06:00:00	12:00:00	f	\N	60
352	65	1	f	t	f	f	f	f	f	t	f	12:00:00	15:00:00	f	\N	45
354	65	1	f	t	f	f	f	f	f	t	f	15:00:00	19:00:00	f	\N	45
376	71	0	t	f	t	t	t	t	t	f	f	06:00:00	09:00:00	f	\N	35
377	71	1	t	f	t	t	t	t	t	f	f	06:00:00	09:00:00	f	\N	35
380	71	0	f	t	t	t	t	t	t	f	f	14:00:00	17:00:00	f	\N	30
381	71	1	f	t	t	t	t	t	t	f	f	14:00:00	17:00:00	f	\N	30
341	65	0	t	t	t	t	t	t	t	f	f	08:00:00	12:00:00	f	\N	60
342	65	1	t	t	t	t	t	t	t	f	f	08:00:00	12:00:00	f	\N	60
350	65	1	t	t	f	f	f	f	f	t	f	06:00:00	12:00:00	f	\N	60
351	65	0	f	t	f	f	f	f	f	t	f	12:00:00	15:00:00	f	\N	45
353	65	0	f	t	f	f	f	f	f	t	f	15:00:00	19:00:00	f	\N	45
382	71	0	f	t	t	t	t	t	t	f	f	17:00:00	19:00:00	f	\N	60
383	71	1	f	t	t	t	t	t	t	f	f	17:00:00	19:00:00	f	\N	60
386	71	0	f	t	f	f	f	f	f	t	f	13:00:00	19:00:00	f	\N	15
387	71	1	f	t	f	f	f	f	f	t	f	13:00:00	19:00:00	f	\N	15
338	64	1	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	10
355	66	0	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	45
356	66	1	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	45
359	66	0	f	t	t	t	t	t	t	t	f	12:00:00	19:00:00	f	\N	120
360	66	1	f	t	t	t	t	t	t	t	f	12:00:00	19:00:00	f	\N	120
361	67	0	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	45
362	67	1	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	45
365	67	0	f	t	t	t	t	t	t	t	f	12:00:00	19:00:00	f	\N	120
366	67	1	f	t	t	t	t	t	t	t	f	12:00:00	19:00:00	f	\N	120
367	68	0	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	45
368	68	1	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	45
371	68	0	f	t	t	t	t	t	t	t	f	12:00:00	19:00:00	f	\N	120
372	68	1	f	t	t	t	t	t	t	t	f	12:00:00	19:00:00	f	\N	120
391	72	1	f	t	t	t	t	t	t	t	f	12:00:00	16:00:00	f	\N	80
388	72	0	t	f	t	t	t	t	t	t	f	08:00:00	10:00:00	f	\N	40
390	72	0	f	t	t	t	t	t	t	t	f	12:00:00	16:00:00	f	\N	80
378	71	0	t	t	t	t	t	t	t	f	f	09:00:00	14:00:00	f	\N	60
379	71	1	t	t	t	t	t	t	t	f	f	09:00:00	14:00:00	f	\N	60
384	71	0	t	t	f	f	f	f	f	t	f	06:00:00	13:00:00	f	\N	120
385	71	1	t	t	f	f	f	f	f	t	f	06:00:00	13:00:00	f	\N	120
392	72	0	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	20
903	180	1	t	t	t	t	t	t	t	t	t	06:30:00	12:00:00	t	\N	25
464	4	1	t	f	t	t	t	t	t	f	f	06:30:00	07:30:00	t	1	60
465	4	0	f	t	t	t	t	t	t	f	f	17:00:00	18:00:00	t	1	60
466	10	0	t	f	t	t	t	t	t	f	f	07:00:00	07:45:00	t	1	45
467	10	1	f	t	t	t	t	t	t	f	f	17:30:00	18:15:00	t	1	45
482	89	1	t	f	t	t	t	t	t	f	f	06:30:00	06:50:00	t	1	20
483	89	0	f	t	t	t	t	t	t	f	f	17:30:00	17:50:00	t	1	20
485	90	1	f	t	t	t	t	t	t	f	f	17:30:00	17:50:00	t	1	20
486	91	1	t	f	t	t	t	t	t	f	f	06:30:00	07:00:00	t	1	30
463	8	1	f	t	t	t	t	t	t	f	f	16:30:00	18:30:00	t	7	20
477	11	1	f	t	f	f	f	f	f	t	t	17:30:00	18:30:00	f	\N	15
476	11	0	t	f	f	f	f	f	f	t	t	06:30:00	08:30:00	f	\N	15
487	91	0	f	t	t	t	t	t	t	f	f	17:30:00	18:00:00	t	1	30
480	11	0	t	f	f	f	f	f	f	t	t	08:30:00	10:30:00	f	\N	20
462	8	0	t	f	t	t	t	t	t	f	f	06:30:00	10:00:00	t	7	30
484	90	0	t	f	t	t	t	t	t	f	f	07:00:00	08:00:00	f	\N	30
488	92	0	t	t	t	t	t	t	t	f	f	06:30:00	18:30:00	f	\N	25
489	92	1	t	t	t	t	t	t	t	f	f	06:30:00	18:30:00	f	\N	25
470	9	0	t	f	t	t	t	t	t	f	f	06:30:00	10:00:00	t	7	30
471	9	1	f	t	t	t	t	t	t	f	f	17:00:00	19:55:00	t	7	25
389	72	1	t	f	t	t	t	t	t	t	f	08:00:00	10:00:00	f	\N	40
864	162	0	f	t	t	t	t	t	t	t	f	15:30:00	19:00:00	f	\N	10
904	180	1	f	t	t	t	t	t	t	t	t	12:30:00	14:30:00	t	\N	15
905	180	1	f	t	t	t	t	t	t	t	t	14:30:00	18:30:00	t	\N	25
712	140	0	t	f	t	t	t	t	t	f	f	05:00:00	09:00:00	f	\N	5
713	140	1	t	f	t	t	t	t	t	f	f	05:00:00	09:00:00	f	\N	5
714	140	0	t	t	t	t	t	t	t	f	f	09:00:00	17:00:00	f	\N	10
715	140	1	t	t	t	t	t	t	t	f	f	09:00:00	17:00:00	f	\N	10
716	140	0	f	t	t	t	t	t	t	f	f	17:00:00	19:00:00	f	\N	5
717	140	1	f	t	t	t	t	t	t	f	f	17:00:00	19:00:00	f	\N	5
718	140	0	f	t	t	t	t	t	t	f	f	19:00:00	22:00:00	f	\N	10
719	140	1	f	t	t	t	t	t	t	f	f	19:00:00	22:00:00	f	\N	10
720	140	0	t	f	f	f	f	f	f	t	t	05:00:00	09:00:00	f	\N	5
721	140	1	t	f	f	f	f	f	f	t	t	05:00:00	09:00:00	f	\N	5
722	140	0	t	t	f	f	f	f	f	t	t	09:00:00	17:00:00	f	\N	10
723	140	1	t	t	f	f	f	f	f	t	t	09:00:00	17:00:00	f	\N	10
724	140	0	f	t	f	f	f	f	f	t	t	17:00:00	19:00:00	f	\N	5
725	140	1	f	t	f	f	f	f	f	t	t	17:00:00	19:00:00	f	\N	5
726	140	0	f	t	f	f	f	f	f	t	t	19:00:00	21:00:00	f	\N	10
727	140	1	f	t	f	f	f	f	f	t	t	19:00:00	21:00:00	f	\N	10
801	148	0	t	t	t	t	t	t	t	t	f	06:00:00	15:00:00	f	\N	120
906	170	0	t	t	f	f	f	f	f	t	t	11:00:00	17:00:00	t	\N	60
829	129	0	t	t	t	t	t	t	t	t	t	10:30:00	17:00:00	f	\N	120
896	168	0	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	120
830	129	1	t	t	t	t	t	t	t	t	t	10:30:00	17:00:00	f	\N	120
827	129	0	t	f	t	t	t	t	t	t	t	07:00:00	10:30:00	f	\N	10
828	129	1	t	f	t	t	t	t	t	t	t	07:00:00	10:30:00	f	\N	10
771	142	0	t	t	t	t	t	t	t	t	t	09:00:00	17:00:00	f	\N	10
772	142	1	t	t	t	t	t	t	t	t	t	09:00:00	17:00:00	f	\N	10
775	142	0	f	t	t	t	t	t	t	t	t	19:00:00	22:15:00	f	\N	10
776	142	1	f	t	t	t	t	t	t	t	t	19:00:00	22:15:00	f	\N	10
769	142	0	t	f	t	t	t	t	t	t	t	05:00:00	09:00:00	f	\N	5
770	142	1	t	f	t	t	t	t	t	t	t	05:00:00	09:00:00	f	\N	5
773	142	0	f	t	t	t	t	t	t	t	t	17:00:00	19:00:00	f	\N	5
774	142	1	f	t	t	t	t	t	t	t	t	17:00:00	19:00:00	f	\N	5
802	149	0	t	t	t	t	t	t	t	t	t	06:00:00	22:00:00	f	\N	5
803	149	1	t	t	t	t	t	t	t	t	t	06:00:00	22:00:00	f	\N	5
831	129	0	f	t	t	t	t	t	t	t	t	17:00:00	22:00:00	f	\N	30
832	129	1	f	t	t	t	t	t	t	t	t	17:00:00	22:00:00	f	\N	30
863	162	1	t	t	t	t	t	t	t	t	f	11:00:00	15:30:00	f	\N	15
70	17	1	t	f	t	t	t	t	t	t	f	07:00:00	07:45:00	t	1	45
71	17	0	f	t	t	t	t	t	t	t	f	17:00:00	17:45:00	t	1	45
77	19	0	t	f	t	t	t	t	t	t	f	06:00:00	10:00:00	t	4	60
78	19	1	t	f	t	t	t	t	t	t	f	06:00:00	10:00:00	t	4	60
67	16	0	t	t	t	t	t	t	t	t	f	07:00:00	13:00:00	f	\N	45
68	16	1	t	t	t	t	t	t	t	t	f	07:00:00	13:00:00	f	\N	45
104	25	0	t	f	t	t	t	t	t	t	f	06:30:00	10:00:00	f	\N	5
105	25	1	t	f	t	t	t	t	t	t	f	06:30:00	10:00:00	f	\N	5
108	25	0	f	t	t	t	t	t	t	t	f	15:01:00	18:00:00	f	\N	5
109	25	1	f	t	t	t	t	t	t	t	f	15:01:00	18:00:00	f	\N	5
65	16	0	t	f	t	t	t	t	t	t	f	04:00:00	07:00:00	f	\N	25
66	16	1	t	f	t	t	t	t	t	t	f	04:00:00	07:00:00	f	\N	25
213	40	0	t	f	t	t	t	t	t	t	f	07:00:00	07:30:00	t	1	30
216	40	1	f	t	t	t	t	t	t	t	f	17:30:00	18:00:00	t	1	30
201	38	0	t	f	t	t	t	t	t	t	f	06:30:00	09:00:00	f	\N	15
206	38	1	f	t	t	t	t	t	t	t	f	15:30:00	18:30:00	f	\N	15
254	47	1	t	f	t	t	t	t	t	t	f	08:00:00	09:40:00	t	2	50
255	47	0	f	t	t	t	t	t	t	t	f	13:00:00	14:40:00	t	2	50
219	41	0	t	t	t	t	t	t	t	t	f	11:00:00	18:00:00	f	\N	45
220	41	1	t	t	t	t	t	t	t	t	f	11:00:00	18:00:00	f	\N	45
116	27	0	t	f	t	t	t	t	t	t	f	06:00:00	07:00:00	f	\N	20
117	27	1	t	f	t	t	t	t	t	t	f	06:00:00	07:00:00	f	\N	20
142	33	0	t	f	t	t	t	t	t	t	f	06:30:00	10:30:00	f	\N	10
143	33	1	t	f	t	t	t	t	t	t	f	06:30:00	10:30:00	f	\N	10
227	43	0	t	t	t	t	t	t	t	t	f	06:00:00	12:00:00	f	\N	20
228	43	1	t	t	t	t	t	t	t	t	f	06:00:00	12:00:00	f	\N	20
249	45	0	t	t	t	t	t	t	t	t	f	06:30:00	18:30:00	f	\N	240
250	45	1	t	t	t	t	t	t	t	t	f	06:30:00	18:30:00	f	\N	240
251	46	0	t	t	t	t	t	t	t	t	f	06:30:00	18:30:00	f	\N	60
252	46	1	t	t	t	t	t	t	t	t	f	06:30:00	18:30:00	f	\N	60
203	38	0	t	t	t	t	t	t	t	t	f	09:00:00	15:30:00	f	\N	35
204	38	1	t	t	t	t	t	t	t	t	f	09:00:00	15:30:00	f	\N	35
217	41	0	t	f	t	t	t	t	t	t	f	06:00:00	11:00:00	f	\N	30
218	41	1	t	f	t	t	t	t	t	t	f	06:00:00	11:00:00	f	\N	30
229	43	0	f	t	t	t	t	t	t	t	f	12:00:00	15:00:00	f	\N	40
230	43	1	f	t	t	t	t	t	t	t	f	12:00:00	15:00:00	f	\N	40
231	43	0	f	t	t	t	t	t	t	t	f	15:00:00	18:00:00	f	\N	20
232	43	1	f	t	t	t	t	t	t	t	f	15:00:00	18:00:00	f	\N	20
279	53	0	f	t	t	t	t	t	t	t	f	12:00:00	14:00:00	f	\N	15
280	53	1	f	t	t	t	t	t	t	t	f	12:00:00	14:00:00	f	\N	15
281	53	0	f	t	t	t	t	t	t	t	f	14:00:00	18:30:00	f	\N	10
282	53	1	f	t	t	t	t	t	t	t	f	14:00:00	18:30:00	f	\N	10
323	63	0	t	f	t	t	t	t	t	t	f	06:00:00	08:00:00	f	\N	10
327	63	0	t	t	t	t	t	t	t	t	f	10:00:00	14:00:00	f	\N	35
328	63	1	t	t	t	t	t	t	t	t	f	10:00:00	14:00:00	f	\N	35
324	63	1	t	f	t	t	t	t	t	t	f	06:00:00	08:00:00	f	\N	10
325	63	0	t	f	t	t	t	t	t	t	f	08:00:00	10:00:00	f	\N	20
333	64	0	t	t	t	t	t	t	t	t	f	06:30:00	13:00:00	f	\N	15
334	64	1	t	t	t	t	t	t	t	t	f	06:30:00	13:00:00	f	\N	15
357	66	0	t	t	t	t	t	t	t	t	f	09:00:00	12:00:00	f	\N	75
358	66	1	t	t	t	t	t	t	t	t	f	09:00:00	12:00:00	f	\N	75
363	67	0	t	t	t	t	t	t	t	t	f	09:00:00	12:00:00	f	\N	60
364	67	1	t	t	t	t	t	t	t	t	f	09:00:00	12:00:00	f	\N	60
369	68	0	t	t	t	t	t	t	t	t	f	09:00:00	12:00:00	f	\N	60
370	68	1	t	t	t	t	t	t	t	t	f	09:00:00	12:00:00	f	\N	60
326	63	1	t	f	t	t	t	t	t	t	f	08:00:00	10:00:00	f	\N	20
329	63	0	f	t	t	t	t	t	t	t	f	14:00:00	16:00:00	f	\N	20
330	63	1	f	t	t	t	t	t	t	t	f	14:00:00	16:00:00	f	\N	20
267	50	0	t	t	t	t	t	t	t	t	f	06:30:00	18:00:00	f	\N	5
335	64	0	f	t	t	t	t	t	t	t	f	13:00:00	16:00:00	f	\N	15
336	64	1	f	t	t	t	t	t	t	t	f	13:00:00	16:00:00	f	\N	15
337	64	0	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	10
421	77	1	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	40
420	77	0	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	40
494	95	0	f	t	t	t	t	t	t	t	f	12:00:00	14:00:00	t	1	120
495	96	0	f	t	t	t	t	t	t	t	f	16:30:00	18:30:00	t	1	120
496	97	0	f	t	t	t	t	t	t	t	f	13:30:00	15:30:00	t	1	120
492	94	0	t	t	t	t	t	t	t	t	f	06:00:00	19:00:00	f	\N	5
493	94	1	t	t	t	t	t	t	t	t	f	06:00:00	19:00:00	f	\N	5
497	98	0	t	f	t	t	t	t	t	t	f	08:00:00	11:00:00	f	\N	45
498	98	1	t	f	t	t	t	t	t	t	f	08:00:00	11:00:00	f	\N	45
499	98	0	t	t	t	t	t	t	t	t	f	11:00:00	18:00:00	f	\N	120
500	98	1	t	t	t	t	t	t	t	t	f	11:00:00	18:00:00	f	\N	120
513	107	0	t	f	t	t	t	t	t	t	f	07:00:00	07:40:00	t	2	20
481	11	1	f	t	t	t	t	t	t	f	f	18:30:00	19:00:00	f	\N	15
474	11	0	t	f	t	t	t	t	t	f	f	06:30:00	08:30:00	f	\N	10
519	108	0	t	f	t	t	t	t	t	t	f	06:30:00	10:30:00	f	\N	30
520	108	1	t	f	t	t	t	t	t	t	f	06:30:00	10:30:00	f	\N	30
522	108	1	t	t	t	t	t	t	t	t	f	10:30:00	15:30:00	f	\N	120
523	108	1	f	t	t	t	t	t	t	t	f	15:30:00	18:30:00	f	\N	20
524	109	0	t	f	t	t	t	t	t	t	f	06:30:00	10:30:00	f	\N	30
525	109	1	t	f	t	t	t	t	t	t	f	06:30:00	10:30:00	f	\N	30
527	109	1	t	t	t	t	t	t	t	t	f	10:30:00	15:30:00	f	\N	120
528	109	1	f	t	t	t	t	t	t	t	f	15:30:00	18:30:00	f	\N	20
475	11	1	f	t	t	t	t	t	t	f	f	17:30:00	18:30:00	f	\N	10
534	111	0	f	t	t	t	t	t	t	t	f	16:00:00	19:00:00	f	\N	30
535	111	1	f	t	t	t	t	t	t	t	f	16:00:00	19:00:00	f	\N	30
536	112	0	t	t	t	t	t	t	t	t	f	08:00:00	19:00:00	f	\N	180
537	112	1	t	t	t	t	t	t	t	t	f	08:00:00	19:00:00	f	\N	180
542	113	0	f	t	t	t	t	t	t	t	f	16:00:00	19:00:00	f	\N	30
543	113	1	f	t	t	t	t	t	t	t	f	16:00:00	19:00:00	f	\N	30
478	11	0	t	f	t	t	t	t	t	f	f	08:30:00	11:00:00	f	\N	20
408	75	0	f	t	t	t	t	t	t	t	f	12:00:00	16:00:00	f	\N	120
409	75	1	f	t	t	t	t	t	t	t	f	12:00:00	16:00:00	f	\N	120
529	110	0	t	t	t	t	t	t	t	t	f	06:00:00	12:00:00	t	2	180
479	11	0	t	t	t	t	t	t	t	f	f	11:00:00	12:00:00	f	\N	30
521	108	0	t	t	t	t	t	t	t	t	f	10:30:00	15:30:00	f	\N	120
526	109	0	t	t	t	t	t	t	t	t	f	10:30:00	15:30:00	f	\N	120
393	72	1	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	20
556	115	0	f	t	t	t	t	t	t	t	f	16:00:00	19:00:00	f	\N	30
557	115	1	f	t	t	t	t	t	t	t	f	16:00:00	19:00:00	f	\N	30
558	115	0	f	t	t	t	t	t	t	t	f	19:00:00	21:00:00	f	\N	60
559	115	1	f	t	t	t	t	t	t	t	f	19:00:00	21:00:00	f	\N	60
560	116	0	t	t	t	t	t	t	t	t	f	06:30:00	17:30:00	f	\N	120
561	116	1	t	t	t	t	t	t	t	t	f	06:30:00	17:30:00	f	\N	120
411	75	1	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	60
407	75	1	t	f	t	t	t	t	t	t	f	08:00:00	10:00:00	f	\N	40
406	75	0	t	f	t	t	t	t	t	t	f	08:00:00	10:00:00	f	\N	40
410	75	0	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	60
419	77	1	t	f	t	t	t	t	t	t	f	06:00:00	10:00:00	f	\N	30
422	77	0	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	15
423	77	1	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	15
418	77	0	t	f	t	t	t	t	t	t	f	06:00:00	10:00:00	f	\N	30
532	111	0	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	120
531	111	1	t	f	t	t	t	t	t	t	f	07:00:00	10:30:00	f	\N	30
533	111	1	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	120
539	113	1	t	f	t	t	t	t	t	t	f	07:00:00	10:30:00	f	\N	30
538	113	0	t	f	t	t	t	t	t	t	f	07:00:00	10:30:00	f	\N	30
541	113	1	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	120
540	113	0	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	120
553	115	1	t	f	t	t	t	t	t	t	f	07:00:00	10:30:00	f	\N	30
554	115	0	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	120
555	115	1	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	120
552	115	0	t	f	t	t	t	t	t	t	f	07:00:00	10:30:00	f	\N	30
596	121	0	f	t	t	t	t	t	t	t	f	16:00:00	17:30:00	f	\N	25
597	121	1	f	t	t	t	t	t	t	t	f	16:00:00	17:30:00	f	\N	25
604	122	0	t	f	t	t	t	t	t	t	f	06:30:00	10:00:00	f	\N	40
605	122	1	t	f	t	t	t	t	t	t	f	06:30:00	10:00:00	f	\N	40
608	122	0	f	t	t	t	t	t	t	t	f	16:00:00	18:30:00	f	\N	30
609	122	1	f	t	t	t	t	t	t	t	f	16:00:00	18:30:00	f	\N	30
610	123	0	t	f	t	t	t	t	t	t	f	07:00:00	10:00:00	f	\N	20
611	123	1	t	f	t	t	t	t	t	t	f	07:00:00	10:00:00	f	\N	20
612	123	0	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	60
613	123	1	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	60
614	123	0	f	t	t	t	t	t	t	t	f	16:00:00	18:30:00	f	\N	20
615	123	1	f	t	t	t	t	t	t	t	f	16:00:00	18:30:00	f	\N	20
618	124	0	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	45
619	124	1	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	45
620	124	0	f	t	t	t	t	t	t	t	f	16:00:00	18:30:00	f	\N	15
621	124	1	f	t	t	t	t	t	t	t	f	16:00:00	18:30:00	f	\N	15
622	125	0	t	f	t	t	t	t	t	t	f	07:00:00	10:00:00	f	\N	40
623	125	1	t	f	t	t	t	t	t	t	f	07:00:00	10:00:00	f	\N	40
624	125	0	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	30
625	125	1	t	t	t	t	t	t	t	t	f	10:00:00	16:00:00	f	\N	30
626	125	0	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	10
627	125	1	f	t	t	t	t	t	t	t	f	16:00:00	18:00:00	f	\N	10
632	128	0	t	t	t	t	t	t	t	t	f	06:30:00	18:00:00	f	\N	40
633	128	1	t	t	t	t	t	t	t	t	f	06:30:00	18:00:00	f	\N	40
638	131	0	t	f	t	t	t	t	t	t	f	05:00:00	09:00:00	f	\N	5
639	131	1	t	f	t	t	t	t	t	t	f	05:00:00	09:00:00	f	\N	5
642	131	0	f	t	t	t	t	t	t	t	f	17:00:00	19:00:00	f	\N	5
643	131	1	f	t	t	t	t	t	t	t	f	17:00:00	19:00:00	f	\N	5
646	132	0	t	f	t	t	t	t	t	t	f	05:00:00	09:00:00	f	\N	5
647	132	1	t	f	t	t	t	t	t	t	f	05:00:00	09:00:00	f	\N	5
650	132	0	f	t	t	t	t	t	t	t	f	17:00:00	19:00:00	f	\N	5
651	132	1	f	t	t	t	t	t	t	t	f	17:00:00	19:00:00	f	\N	5
654	76	0	t	f	t	t	t	t	t	t	f	06:30:00	07:00:00	f	\N	30
655	76	1	t	f	t	t	t	t	t	t	f	06:30:00	07:00:00	f	\N	30
656	76	0	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	f	\N	10
657	76	1	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	f	\N	10
658	76	0	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	30
659	76	1	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	30
660	76	0	f	t	t	t	t	t	t	t	f	17:00:00	18:30:00	f	\N	10
661	76	1	f	t	t	t	t	t	t	t	f	17:00:00	18:30:00	f	\N	10
678	135	0	t	f	t	t	t	t	t	t	f	05:00:00	09:00:00	f	\N	5
679	135	1	t	f	t	t	t	t	t	t	f	05:00:00	09:00:00	f	\N	5
680	135	0	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	10
681	135	1	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	10
682	135	0	f	t	t	t	t	t	t	t	f	17:00:00	19:00:00	f	\N	5
683	135	1	f	t	t	t	t	t	t	t	f	17:00:00	19:00:00	f	\N	5
592	121	0	t	f	t	t	t	t	t	t	f	06:30:00	10:00:00	f	\N	30
593	121	1	t	f	t	t	t	t	t	t	f	06:30:00	10:00:00	f	\N	30
684	135	0	f	t	t	t	t	t	t	t	f	19:00:00	22:15:00	f	\N	10
685	135	1	f	t	t	t	t	t	t	t	f	19:00:00	22:15:00	f	\N	10
696	138	0	t	f	t	t	t	t	t	t	f	05:00:00	09:00:00	f	\N	5
697	138	1	t	f	t	t	t	t	t	t	f	05:00:00	09:00:00	f	\N	5
698	138	0	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	10
699	138	1	t	t	t	t	t	t	t	t	f	09:00:00	17:00:00	f	\N	10
700	138	0	f	t	t	t	t	t	t	t	f	17:00:00	19:00:00	f	\N	5
701	138	1	f	t	t	t	t	t	t	t	f	17:00:00	19:00:00	f	\N	5
702	138	0	f	t	t	t	t	t	t	t	f	19:00:00	22:15:00	f	\N	10
703	138	1	f	t	t	t	t	t	t	t	f	19:00:00	22:15:00	f	\N	10
686	136	0	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	t	2	60
687	136	1	t	f	t	t	t	t	t	t	f	07:00:00	09:00:00	t	2	60
835	155	0	t	f	t	t	t	t	t	t	f	06:30:00	10:30:00	t	2	120
28	12	1	t	f	t	t	t	t	t	t	t	07:00:00	09:00:00	f	\N	5
32	12	1	f	t	t	t	t	t	t	t	t	14:00:00	16:00:00	f	\N	20
838	158	0	t	t	t	t	t	t	t	t	f	07:00:00	19:30:00	f	\N	120
839	158	1	t	t	t	t	t	t	t	t	f	07:00:00	19:30:00	f	\N	120
860	162	0	t	f	t	t	t	t	t	t	f	06:00:00	11:00:00	f	\N	5
861	162	1	t	f	t	t	t	t	t	t	f	06:00:00	11:00:00	f	\N	5
31	12	0	f	t	t	t	t	t	t	t	t	14:00:00	16:00:00	f	\N	20
27	12	0	t	f	t	t	t	t	t	t	t	07:00:00	09:00:00	f	\N	5
760	144	0	t	t	t	t	t	t	t	t	f	06:00:00	12:00:00	t	2	180
836	156	0	t	t	t	t	t	t	t	t	f	07:30:00	12:00:00	t	3	90
866	163	0	t	f	t	t	t	t	t	t	f	06:00:00	11:00:00	f	\N	5
867	163	1	t	f	t	t	t	t	t	t	f	06:00:00	11:00:00	f	\N	5
837	157	0	t	t	t	t	t	t	t	t	f	07:30:00	12:00:00	t	3	90
806	126	0	t	t	t	t	t	t	t	t	f	06:00:00	12:00:00	f	\N	180
872	164	0	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	10
873	164	1	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	10
874	164	0	t	t	t	t	t	t	t	t	f	09:00:00	13:00:00	f	\N	20
875	164	1	t	t	t	t	t	t	t	t	f	09:00:00	13:00:00	f	\N	20
876	164	0	f	t	t	t	t	t	t	t	f	13:00:00	19:00:00	f	\N	10
877	164	1	f	t	t	t	t	t	t	t	f	13:00:00	19:00:00	f	\N	10
878	164	0	f	t	t	t	t	t	t	t	f	19:00:00	22:00:00	f	\N	20
879	164	1	f	t	t	t	t	t	t	t	f	19:00:00	22:00:00	f	\N	20
880	165	0	t	t	t	t	t	t	t	t	f	06:00:00	22:00:00	f	\N	5
881	165	1	t	t	t	t	t	t	t	t	f	06:00:00	22:00:00	f	\N	5
882	166	0	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	10
883	166	1	t	f	t	t	t	t	t	t	f	06:00:00	09:00:00	f	\N	10
884	166	0	t	t	t	t	t	t	t	t	f	09:00:00	13:00:00	f	\N	30
885	166	1	t	t	t	t	t	t	t	t	f	09:00:00	13:00:00	f	\N	30
886	166	0	f	t	t	t	t	t	t	t	f	13:00:00	19:00:00	f	\N	10
887	166	1	f	t	t	t	t	t	t	t	f	13:00:00	19:00:00	f	\N	10
888	166	0	f	t	t	t	t	t	t	t	f	19:00:00	22:00:00	f	\N	30
889	166	1	f	t	t	t	t	t	t	t	f	19:00:00	22:00:00	f	\N	30
869	163	1	t	t	t	t	t	t	t	t	f	11:00:00	15:30:00	f	\N	10
895	168	1	t	f	t	t	t	t	t	t	f	07:00:00	10:30:00	f	\N	30
868	163	0	t	t	t	t	t	t	t	t	f	11:00:00	15:30:00	f	\N	10
146	33	0	f	t	t	t	t	t	t	t	f	16:00:00	18:30:00	f	\N	10
147	33	1	f	t	t	t	t	t	t	t	f	16:00:00	18:30:00	f	\N	10
106	25	0	t	t	t	t	t	t	t	t	f	10:00:00	15:01:00	f	\N	15
107	25	1	t	t	t	t	t	t	t	t	f	10:00:00	15:01:00	f	\N	15
120	27	0	t	t	t	t	t	t	t	t	f	09:00:00	18:45:00	f	\N	25
121	27	1	t	t	t	t	t	t	t	t	f	09:00:00	18:45:00	f	\N	25
126	28	0	t	t	t	t	t	t	t	t	f	09:00:00	18:45:00	f	\N	25
127	28	1	t	t	t	t	t	t	t	t	f	09:00:00	18:45:00	f	\N	25
132	29	0	t	t	t	t	t	t	t	t	f	09:00:00	18:45:00	f	\N	25
133	29	1	t	t	t	t	t	t	t	t	f	09:00:00	18:45:00	f	\N	25
144	33	0	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	30
145	33	1	t	t	t	t	t	t	t	t	f	10:30:00	16:00:00	f	\N	30
833	154	0	t	t	t	t	t	t	t	t	t	07:00:00	18:30:00	f	\N	45
834	154	1	t	t	t	t	t	t	t	t	t	07:00:00	18:30:00	f	\N	45
862	162	0	t	t	t	t	t	t	t	t	f	11:00:00	15:30:00	f	\N	15
43	13	0	f	t	t	t	t	t	t	t	t	14:00:00	16:00:00	f	\N	20
44	13	1	f	t	t	t	t	t	t	t	t	14:00:00	16:00:00	f	\N	20
39	13	0	t	f	t	t	t	t	t	t	t	07:00:00	09:00:00	f	\N	5
40	13	1	t	f	t	t	t	t	t	t	t	07:00:00	09:00:00	f	\N	5
52	14	1	t	f	t	t	t	t	t	t	t	07:00:00	09:00:00	f	\N	5
51	14	0	t	f	t	t	t	t	t	t	t	07:00:00	09:00:00	f	\N	5
55	14	0	f	t	t	t	t	t	t	t	t	14:00:00	16:00:00	f	\N	20
56	14	1	f	t	t	t	t	t	t	t	t	14:00:00	16:00:00	f	\N	20
\.


--
-- Data for Name: route_stops; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.route_stops (route_stop_id, route_id, modified_at, stop_id, stop_order, duration_to_stop, cost_to_stop, is_stop_mandatory) FROM stdin;
41	4	2026-02-06 10:44:23.200593	2	1	0	0	Yes
517	171	2026-03-30 15:10:35.053442	3	1	0	0	Yes
518	171	2026-03-30 15:10:35.114442	96	2	9999	1	Yes
519	171	2026-03-30 15:10:35.153143	7	3	9999	1	Yes
520	171	2026-03-30 15:10:35.185003	2	4	9999	1	Yes
54	8	2026-02-06 10:44:23.242632	2	3	10	2200	Yes
60	10	2026-02-06 10:44:23.26344	10	2	40	2200	Yes
521	172	2026-03-30 15:14:50.823005	31	1	0	0	Yes
522	172	2026-03-30 15:14:50.884083	96	2	9999	1	Yes
523	172	2026-03-30 15:14:50.916456	7	3	9999	1	Yes
149	40	2026-02-10 12:27:52.973	2	3	5	3000	Yes
73	16	2026-02-09 10:35:32.581	10	1	0	0	Yes
76	17	2026-02-09 10:57:15.008	10	1	0	0	Yes
57	9	2026-02-06 10:44:23.253675	6	3	10	2200	Yes
82	19	2026-02-09 11:11:38.152	10	1	0	0	Yes
524	172	2026-03-30 15:14:50.94838	2	4	9999	1	Yes
78	17	2026-02-09 10:57:15.008	2	3	10	2500	Yes
79	17	2026-02-09 10:57:15.008	200	4	25	2500	Yes
113	31	2026-02-09 14:46:22.095	4	3	20	10000	Yes
116	32	2026-02-09 14:49:47.834	140	3	40	9000	Yes
564	179	2026-04-07 16:03:57.984378	21	2	5	100	Depends on the passengers' demands
568	180	2026-04-07 16:18:54.086809	41	2	5	100	Yes
155	43	2026-02-11 09:25:59.655	144	2	5	400	Yes
96	24	2026-02-09 11:37:42.522	10	1	0	0	Yes
98	25	2026-02-09 12:03:26.22	38	1	0	0	Yes
157	44	2026-02-11 10:44:11.843	145	2	7	500	Yes
102	27	2026-02-09 13:45:27.339	70	1	0	0	Yes
42	4	2026-02-06 10:44:23.202791	14	2	25	3500	Yes
104	28	2026-02-09 13:46:10.555	70	1	0	0	Yes
35	1	2026-02-06 10:44:23.178662	4	3	90	15000	Yes
106	29	2026-02-09 13:47:07.727	70	1	0	0	Yes
563	179	2026-04-07 16:03:57.940517	23	1	0	0	Yes
108	30	2026-02-09 13:53:15.585	70	1	0	0	Yes
109	30	2026-02-09 13:53:15.585	120	2	10	1000	Yes
110	30	2026-02-09 13:53:15.585	62	3	15	1000	Yes
111	31	2026-02-09 14:46:22.095	18	1	0	0	Yes
114	32	2026-02-09 14:49:47.834	18	1	0	0	Yes
115	32	2026-02-09 14:49:47.834	13	2	60	5000	Yes
117	33	2026-02-09 14:52:56.801	18	1	0	0	Yes
112	31	2026-02-09 14:46:22.095	139	2	100	9000	Yes
65	12	2026-02-09 08:44:22.291	27	1	0	0	Yes
67	13	2026-02-09 08:46:02.911	27	1	0	0	Yes
69	14	2026-02-09 08:47:47.182	27	1	0	0	Yes
33	1	2026-02-06 10:44:23.169471	1	1	0	0	Yes
34	1	2026-02-06 10:44:23.175061	13	2	90	10000	Depends on the passengers' demands
565	179	2026-04-07 16:03:58.01532	112	3	10	100	Depends on the passengers' demands
566	179	2026-04-07 16:03:58.045736	22	4	5	100	Yes
139	37	2026-02-10 10:09:51.269	14	1	0	0	Yes
64	11	2026-02-06 10:44:23.278251	2	4	5	3500	Yes
150	41	2026-02-10 13:02:56.74	109	1	0	0	Yes
567	180	2026-04-07 16:18:53.97284	51	1	0	0	Yes
154	43	2026-02-11 09:25:59.655	71	1	0	0	Yes
569	181	2026-04-21 10:10:29.176243	79	1	0	0	Yes
167	49	2026-02-11 13:32:23.942	10	2	30	1200	Yes
168	49	2026-02-11 13:32:23.942	6	3	20	1500	Yes
169	50	2026-02-12 08:11:04.563	23	1	0	0	Yes
177	53	2026-02-13 09:42:16.307	51	1	0	0	Yes
570	181	2026-04-21 10:10:29.280323	222	2	8	300	Yes
58	9	2026-02-06 10:44:23.256237	5	4	5	2200	Yes
74	16	2026-02-09 10:35:32.581	27	2	8	400	Yes
143	38	2026-02-10 12:23:52.647	69	1	0	0	Yes
147	40	2026-02-10 12:27:52.973	69	1	0	0	Yes
156	44	2026-02-11 10:44:11.843	63	1	0	0	Yes
75	16	2026-02-09 10:35:32.581	121	3	7	400	Yes
179	54	2026-02-13 10:37:31.148	83	1	0	0	Yes
133	34	2026-02-10 09:15:04.636	15	1	0	0	Yes
137	36	2026-02-10 09:24:37.357	15	1	0	0	Yes
148	40	2026-02-10 12:27:52.973	7	2	25	3000	Yes
158	45	2026-02-11 13:11:40.484	9	1	0	0	Yes
160	46	2026-02-11 13:14:26.419	9	1	0	0	Yes
162	47	2026-02-11 13:25:15.377	9	1	0	0	Yes
77	17	2026-02-09 10:57:15.008	6	2	10	2500	Yes
164	48	2026-02-11 13:28:20.508	9	1	0	0	Yes
83	19	2026-02-09 11:11:38.152	35	2	10	2000	Yes
144	38	2026-02-10 12:23:52.647	8	2	10	2000	Yes
97	24	2026-02-09 11:37:42.522	130	2	30	500	Yes
136	34	2026-02-10 09:15:04.64	2	2	30	2500	Yes
163	47	2026-02-11 13:25:15.377	77	2	45	2000	Yes
140	37	2026-02-10 10:09:51.269	12	2	20	2700	Yes
118	33	2026-02-09 14:52:56.801	80	2	20	4000	Yes
142	37	2026-02-10 10:09:51.269	2	4	5	2700	Yes
141	37	2026-02-10 10:09:51.269	7	3	5	2700	Yes
166	49	2026-02-11 13:32:23.942	9	1	0	0	Yes
525	173	2026-03-30 15:17:22.167093	3	1	0	0	Yes
239	72	2026-02-20 12:12:00.217	200	2	45	2500	Yes
245	75	2026-02-20 12:15:51.263	1	2	5	700	Depends on the passengers' demands
246	75	2026-02-20 12:15:51.263	3	3	35	2500	Yes
250	77	2026-02-20 12:31:01.47	101	2	30	2500	Yes
52	8	2026-02-06 10:44:23.234485	3	1	0	0	Yes
55	9	2026-02-06 10:44:23.248604	3	1	0	0	Yes
59	10	2026-02-06 10:44:23.259052	3	1	0	0	Yes
61	11	2026-02-06 10:44:23.266802	3	1	0	0	Yes
526	173	2026-03-30 15:17:22.198902	5	2	9999	1	Yes
56	9	2026-02-06 10:44:23.251219	1	2	30	2200	Yes
70	14	2026-02-09 08:47:47.182	121	2	8	400	Yes
107	29	2026-02-09 13:47:07.727	59	2	2	300	Yes
105	28	2026-02-09 13:46:10.555	125	2	2	300	Yes
103	27	2026-02-09 13:45:27.339	30	2	2	300	Yes
200	63	2026-02-18 15:27:07.341	10	1	0	0	Yes
202	64	2026-02-18 15:44:51.344	10	1	0	0	Yes
203	64	2026-02-18 15:44:51.344	64	2	10	200	Yes
204	64	2026-02-18 15:44:51.344	78	3	10	400	Depends on the passengers' demands
205	64	2026-02-18 15:44:51.344	84	4	15	400	Yes
206	65	2026-02-18 21:02:57.741	107	1	0	0	Yes
207	65	2026-02-18 21:02:57.741	89	2	15	1000	Depends on the passengers' demands
208	65	2026-02-18 21:02:57.741	73	3	5	1500	Depends on the passengers' demands
210	65	2026-02-18 21:02:57.741	122	5	5	1500	Depends on the passengers' demands
211	65	2026-02-18 21:02:57.741	135	6	3	1500	Depends on the passengers' demands
212	65	2026-02-18 21:02:57.741	100	7	2	1500	Depends on the passengers' demands
213	65	2026-02-18 21:02:57.741	77	8	3	1500	Yes
214	66	2026-02-18 21:34:05.46	89	1	0	0	Yes
216	67	2026-02-18 23:19:26.76	73	1	0	0	Yes
217	67	2026-02-18 23:19:26.76	89	2	5	1000	Depends on the passengers' demands
218	67	2026-02-18 23:19:26.76	107	3	15	1500	Yes
219	68	2026-02-18 23:21:08.232	74	1	0	0	Yes
220	68	2026-02-18 23:21:08.232	89	2	5	1000	Depends on the passengers' demands
221	68	2026-02-18 23:21:08.232	107	3	15	1500	Yes
180	54	2026-02-13 10:37:31.148	142	2	3	300	Yes
62	11	2026-02-06 10:44:23.271191	12	2	20	3500	Depends on the passengers' demands
63	11	2026-02-06 10:44:23.27559	7	3	5	3500	Yes
227	71	2026-02-20 11:07:46.599	60	1	0	0	Yes
228	71	2026-02-20 11:07:46.599	114	2	1	500	Depends on the passengers' demands
229	71	2026-02-20 11:07:46.599	62	3	3	500	Depends on the passengers' demands
230	71	2026-02-20 11:07:46.599	44	4	2	500	Depends on the passengers' demands
231	71	2026-02-20 11:07:46.599	119	5	2	500	Depends on the passengers' demands
232	71	2026-02-20 11:07:46.599	93	6	3	500	Depends on the passengers' demands
233	71	2026-02-20 11:07:46.599	120	7	3	500	Depends on the passengers' demands
235	71	2026-02-20 11:07:46.599	30	9	1	1000	Depends on the passengers' demands
236	71	2026-02-20 11:07:46.599	125	10	1	1000	Depends on the passengers' demands
237	71	2026-02-20 11:07:46.599	70	11	1	1500	Yes
238	72	2026-02-20 12:12:00.217	7	1	0	0	Yes
528	173	2026-03-30 15:17:22.259573	10	3	9999	1	Yes
53	8	2026-02-06 10:44:23.237876	7	2	20	2200	Yes
244	75	2026-02-20 12:15:51.263	5	1	0	0	Yes
249	77	2026-02-20 12:31:01.47	36	1	0	0	Yes
209	65	2026-02-18 21:02:57.741	74	4	2	1500	Depends on the passengers' demands
234	71	2026-02-20 11:07:46.599	59	8	3	1000	Depends on the passengers' demands
201	63	2026-02-18 15:27:07.341	85	2	9	400	Yes
215	66	2026-02-18 21:34:05.46	107	2	15	1000	Yes
178	53	2026-02-13 09:42:16.307	141	2	2	100	Yes
138	36	2026-02-10 09:24:37.357	10	2	40	2200	Yes
159	45	2026-02-11 13:11:40.484	81	2	37	1500	Yes
165	48	2026-02-11 13:28:20.508	19	2	40	1000	Yes
161	46	2026-02-11 13:14:26.419	74	2	40	1500	Yes
170	50	2026-02-12 08:11:04.563	20	2	2	50	Yes
529	174	2026-03-30 15:20:18.860384	1	1	0	0	Yes
530	174	2026-03-30 15:20:18.892606	6	2	9999	1	Yes
306	103	2026-02-25 18:21:35.696	1	2	40	3000	Depends on the passengers' demands
307	103	2026-02-25 18:21:35.696	6	3	10	3500	Yes
275	89	2026-02-25 09:32:40.256	69	2	10	2000	Yes
277	90	2026-02-25 09:35:59.506	2	2	40	3000	Yes
279	91	2026-02-25 09:37:40.224	58	2	15	2000	Yes
324	108	2026-02-25 20:54:40.991	10	2	25	2500	Depends on the passengers' demands
327	109	2026-02-25 20:57:55.139	101	2	20	3000	Yes
284	94	2026-02-25 10:04:53.357	86	1	0	0	Yes
285	94	2026-02-25 10:04:53.357	152	2	2	200	Yes
286	95	2026-02-25 12:42:07.429	46	1	0	0	Yes
287	95	2026-02-25 12:42:07.429	153	2	150	8000	Yes
288	96	2026-02-25 12:43:55.983	46	1	0	0	Yes
289	96	2026-02-25 12:43:55.983	154	2	110	3500	Yes
290	97	2026-02-25 12:45:39.091	46	1	0	0	Yes
291	97	2026-02-25 12:45:39.091	17	2	60	1500	Yes
292	98	2026-02-25 12:48:55.259	46	1	0	0	Yes
293	98	2026-02-25 12:48:55.259	155	2	20	300	Yes
335	112	2026-02-27 09:51:54.484	60	2	30	1500	Yes
559	178	2026-03-30 15:33:55.422218	10	1	0	0	Yes
560	178	2026-03-30 15:33:55.455512	38	2	9999	1	Yes
561	178	2026-03-30 15:33:55.486775	101	3	9999	1	Yes
337	113	2026-02-27 09:55:26.927	74	2	25	1500	Yes
341	115	2026-02-27 10:15:22.948	19	2	15	1500	Yes
562	178	2026-03-30 15:33:55.517957	36	4	9999	1	Yes
364	123	2026-02-27 12:04:26.134	70	2	20	2500	Yes
305	103	2026-02-25 18:21:35.696	58	1	0	0	Yes
366	124	2026-02-27 12:18:06.783	1	2	10	1000	Depends on the passengers' demands
367	124	2026-02-27 12:18:06.783	3	3	30	2500	Yes
343	116	2026-02-27 11:02:08.795	13	2	65	4500	Depends on the passengers' demands
344	116	2026-02-27 11:02:08.795	4	3	70	12000	Yes
319	107	2026-02-25 18:41:11.417	6	3	35	3500	Yes
377	128	2026-02-27 12:33:35.19	10	2	25	2000	Yes
317	107	2026-02-25 18:41:11.417	42	1	0	0	Yes
318	107	2026-02-25 18:41:11.417	7	2	30	2500	Depends on the passengers' demands
362	122	2026-02-27 11:40:55.555	10	3	15	2500	Yes
361	122	2026-02-27 11:40:55.555	121	2	15	2500	Depends on the passengers' demands
66	12	2026-02-09 08:44:22.291	99	2	4	300	Yes
323	108	2026-02-25 20:54:40.991	92	1	0	0	Yes
326	109	2026-02-25 20:57:55.139	92	1	0	0	Yes
328	110	2026-02-27 08:40:20.896	101	1	0	0	Yes
329	110	2026-02-27 08:40:20.896	146	2	120	10000	Yes
330	110	2026-02-27 08:40:20.896	4	3	30	12000	Yes
331	111	2026-02-27 09:42:15.519	107	1	0	0	Yes
332	111	2026-02-27 09:42:15.519	89	2	15	1500	Yes
333	111	2026-02-27 09:42:15.519	77	3	5	1500	Yes
334	112	2026-02-27 09:51:54.484	107	1	0	0	Yes
336	113	2026-02-27 09:55:26.927	107	1	0	0	Yes
68	13	2026-02-09 08:46:02.911	91	2	4	300	Yes
281	92	2026-02-25 09:41:51.816	86	2	5	400	Yes
340	115	2026-02-27 10:15:22.948	107	1	0	0	Yes
342	116	2026-02-27 11:02:08.795	92	1	0	0	Yes
99	25	2026-02-09 12:03:26.22	67	2	10	600	Yes
151	41	2026-02-10 13:02:56.74	31	2	7	2500	Yes
354	121	2026-02-27 11:36:31.736	36	1	0	0	Yes
355	121	2026-02-27 11:36:31.736	101	2	20	1000	Depends on the passengers' demands
356	121	2026-02-27 11:36:31.736	92	3	15	1500	Yes
360	122	2026-02-27 11:40:55.555	36	1	0	0	Yes
363	123	2026-02-27 12:04:26.134	92	1	0	0	Yes
365	124	2026-02-27 12:18:06.783	6	1	0	0	Yes
368	125	2026-02-27 12:21:42.564	6	1	0	0	Yes
369	125	2026-02-27 12:21:42.564	106	2	10	1000	Depends on the passengers' demands
370	125	2026-02-27 12:21:42.564	130	3	9	2000	Yes
376	128	2026-02-27 12:33:35.19	6	1	0	0	Yes
274	89	2026-02-25 09:32:40.256	200	1	0	0	Yes
276	90	2026-02-25 09:35:59.506	200	1	0	0	Yes
278	91	2026-02-25 09:37:40.224	200	1	0	0	Yes
280	92	2026-02-25 09:41:51.816	200	1	0	0	Yes
325	108	2026-02-25 20:54:40.991	6	3	15	3000	Yes
531	175	2026-03-30 15:22:44.503536	118	1	0	0	Yes
383	131	2026-02-27 15:04:34.138	124	1	0	0	Yes
384	131	2026-02-27 15:04:34.138	104	2	7	50	Yes
385	132	2026-02-27 15:05:21.084	102	1	0	0	Yes
386	132	2026-02-27 15:05:21.084	104	2	7	50	Yes
387	76	2026-02-27 15:17:35.065	5	1	0	0	Yes
473	157	2026-03-03 09:16:01.543	1	8	10	10000	Yes
459	156	2026-03-03 09:15:26.92	57	2	50	10000	Yes
427	148	2026-02-28 00:25:18.503	74	3	2	1500	Depends on the passengers' demands
462	156	2026-03-03 09:15:26.92	101	5	5	10000	Yes
393	135	2026-02-27 15:24:57.243	105	1	0	0	Yes
394	135	2026-02-27 15:24:57.243	147	2	5	50	Yes
396	136	2026-02-27 15:25:13.709	2	2	10	1000	Depends on the passengers' demands
532	175	2026-03-30 15:22:44.536626	32	2	9999	1	Yes
490	163	2026-03-05 03:24:07.114	84	2	5	500	Yes
464	156	2026-03-03 09:15:26.92	6	7	10	10000	Yes
400	138	2026-02-27 15:35:41.799	35	1	0	0	Yes
401	138	2026-02-27 15:35:41.799	16	2	5	50	Yes
472	157	2026-03-03 09:16:01.543	6	7	10	10000	Yes
460	156	2026-03-03 09:15:26.92	18	3	60	10000	Yes
404	140	2026-02-27 21:25:24.138	55	1	0	0	Yes
405	140	2026-02-27 21:25:24.138	75	2	5	150	Yes
471	157	2026-03-03 09:16:01.543	10	6	5	10000	Yes
467	157	2026-03-03 09:16:01.543	57	2	50	10000	Yes
461	156	2026-03-03 09:15:26.92	92	4	10	10000	Yes
412	144	2026-02-27 21:57:52.43	101	1	0	0	Yes
413	144	2026-02-27 21:57:52.43	139	2	120	10000	Yes
414	144	2026-02-27 21:57:52.43	4	3	30	12000	Yes
477	73	2026-03-04 00:35:16.999	3	2	35	3500	Yes
388	76	2026-02-27 15:17:35.065	6	2	5	700	Yes
417	142	2026-02-27 22:04:14.919	149	1	0	0	Yes
418	142	2026-02-27 22:04:14.919	151	2	5	50	Yes
469	157	2026-03-03 09:16:01.543	92	4	10	10000	Yes
465	156	2026-03-03 09:15:26.92	1	8	10	10000	Yes
425	148	2026-02-28 00:25:18.503	60	1	0	0	Yes
426	148	2026-02-28 00:25:18.503	73	2	15	1500	Depends on the passengers' demands
428	148	2026-02-28 00:25:18.503	77	4	10	1500	Depends on the passengers' demands
429	148	2026-02-28 00:25:18.503	89	5	10	1500	Depends on the passengers' demands
430	148	2026-02-28 00:25:18.503	107	6	15	2000	Yes
431	149	2026-02-28 14:41:07.223	129	1	0	0	Yes
432	149	2026-02-28 14:41:07.223	24	2	3	100	Yes
435	126	2026-02-28 15:56:43.025	6	1	0	0	Yes
436	126	2026-02-28 15:56:43.025	13	2	120	11000	Depends on the passengers' demands
437	126	2026-02-28 15:56:43.025	4	3	60	11000	Yes
534	175	2026-03-30 15:22:44.599526	1	3	9999	1	Yes
535	175	2026-03-30 15:22:44.630419	5	4	9999	1	Yes
536	175	2026-03-30 15:22:44.662313	6	5	9999	1	Yes
537	175	2026-03-30 15:22:44.694387	2	6	9999	1	Yes
503	166	2026-03-06 15:05:12.926	10	7	5	800	Yes
470	157	2026-03-03 09:16:01.543	101	5	5	10000	Yes
452	129	2026-02-28 16:26:03.606	121	2	25	700	Yes
454	154	2026-02-28 16:31:06.07	106	2	10	1000	Yes
483	160	2026-03-04 00:38:42.648	14	2	25	3500	Yes
451	129	2026-02-28 16:26:03.606	6	1	0	0	Yes
453	154	2026-02-28 16:31:06.07	6	1	0	0	Yes
455	155	2026-03-03 08:48:57.96	42	1	0	0	Yes
456	155	2026-03-03 08:48:57.96	1	2	45	3000	Depends on the passengers' demands
457	155	2026-03-03 08:48:57.96	6	3	15	3000	Yes
458	156	2026-03-03 09:15:26.92	4	1	0	0	Yes
466	157	2026-03-03 09:16:01.543	156	1	0	0	Yes
474	158	2026-03-03 09:48:16.751	88	1	0	0	Yes
475	158	2026-03-03 09:48:16.751	157	2	30	500	Yes
476	73	2026-03-04 00:35:16.999	7	1	0	0	Yes
478	159	2026-03-04 00:36:25.377	7	1	0	0	Yes
479	159	2026-03-04 00:36:25.377	15	2	25	2000	Yes
480	74	2026-03-04 00:37:29.881	7	1	0	0	Yes
481	74	2026-03-04 00:37:29.881	31	2	30	2500	Yes
482	160	2026-03-04 00:38:42.648	7	1	0	0	Yes
484	161	2026-03-04 00:39:44.239	7	1	0	0	Yes
485	161	2026-03-04 00:39:44.239	69	2	35	2500	Yes
486	162	2026-03-05 03:21:16.052	64	1	0	0	Yes
487	162	2026-03-05 03:21:16.052	85	2	5	200	Depends on the passengers' demands
488	162	2026-03-05 03:21:16.052	10	3	10	500	Yes
489	163	2026-03-05 03:24:07.114	64	1	0	0	Yes
491	164	2026-03-05 15:08:16.184	84	1	0	0	Yes
492	164	2026-03-05 15:08:16.184	64	2	15	200	Depends on the passengers' demands
493	164	2026-03-05 15:08:16.184	85	3	10	200	Depends on the passengers' demands
494	164	2026-03-05 15:08:16.184	10	4	10	500	Yes
497	166	2026-03-06 15:05:12.926	129	1	0	0	Yes
395	136	2026-02-27 15:25:13.709	6	1	0	0	Yes
463	156	2026-03-03 09:15:26.92	10	6	5	10000	Yes
495	165	2026-03-06 14:12:38.091	78	1	0	0	Yes
496	165	2026-03-06 14:12:38.091	84	2	5	200	Yes
498	166	2026-03-06 15:05:12.926	24	2	5	200	Depends on the passengers' demands
499	166	2026-03-06 15:05:12.926	90	3	10	300	Depends on the passengers' demands
500	166	2026-03-06 15:05:12.926	78	4	5	300	Depends on the passengers' demands
501	166	2026-03-06 15:05:12.926	64	5	5	400	Depends on the passengers' demands
502	166	2026-03-06 15:05:12.926	85	6	5	400	Depends on the passengers' demands
468	157	2026-03-03 09:16:01.543	18	3	60	10000	Yes
507	168	2026-03-06 21:23:05.205	81	1	0	0	Yes
508	168	2026-03-06 21:23:05.205	107	2	20	1500	Yes
538	176	2026-03-30 15:25:49.815952	6	1	0	0	Yes
539	176	2026-03-30 15:25:49.855518	27	2	9999	1	Yes
397	136	2026-02-27 15:25:13.709	200	3	50	3000	Yes
513	23	2026-03-13 12:58:02.034638	10	1	0	0	Yes
515	170	2026-03-24 12:09:59.029673	54	1	0	0	Yes
516	170	2026-03-24 12:09:59.140171	130	2	30	15000	Yes
541	176	2026-03-30 15:25:49.917871	10	3	9999	1	Yes
542	176	2026-03-30 15:25:49.949362	55	4	9999	1	Yes
543	176	2026-03-30 15:25:49.982212	59	5	9999	1	Yes
544	176	2026-03-30 15:25:50.014948	9	6	9999	1	Yes
514	23	2026-03-13 12:58:02.139816	57	2	75	3500	Yes
\.


--
-- Data for Name: route_submissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.route_submissions (route_submission_id, route_id, submitted_at, origin, destination, operator, payment_options, boat_types, weekend_equals_weekday_schedule, saturday_equals_sunday_schedule, total_base_duration, total_base_cost, hyacinth_season_disruption, rain, route_stops, stop_names, additional_notes, contact_name, contact_email, status) FROM stdin;
72	63	2026-02-18 15:27:07.341	Liverpool (Apapa)	Itu Agan	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	9	400	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		Market days are the greatest time to take this route. The market days are tuesdays, fridays, and saturdays, and wait times are almost nonexistent these days. Ideally, boat operators should not take trips after 6:00pm, but many do and close by 8: 00pm	Fisayo 	fisayo@publictech.studio	applied
73	64	2026-02-18 15:44:51.344	Liverpool (Apapa)	Isoda	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	t	f	35	400	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Igbo-Elejo", "Ilutuntun"]	Igbo-Elejo, Ilutuntun	\N	Fisayo 	fisayo@publictech.studio	applied
74	65	2026-02-18 21:02:57.741	Ojo market waterside	Ilashe	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Bank Transfer, Cash	Banana, Wooden boats	f	t	45	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	["Iyagbe", "Ikare palace", "Ikare town landing", "Salt Beach", "Uncle Ben", "Mikano"]	Iyagbe, Ikare palace, Ikare town landing, Salt Beach, Uncle Ben, Mikano	The trip frequency increases on saturday evenings because of the beach houses along the route, and also there other minor stops on the route. The cumulative time from Ojo waterside to Ilashe is usually between 40mins-50mins	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	applied
75	66	2026-02-18 21:34:05.46	Iyagbe	Ojo market waterside	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Wooden boats, Banana	t	f	15	1000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	\N		This route is mostly busy in the early morning, when market people are going to trade, in the afternoon to late evenings there is scanty activities	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	applied
76	67	2026-02-18 23:19:26.76	Ikare palace	Ojo market waterside	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	t	f	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	["Iyagbe"]	Iyagbe	Ikare village is very small, and the population reflects that, most of the boat actvities take place in the morning, when they go to the market at ojo	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	applied
80	71	2026-02-20 11:07:46.599	Ibese	Ijegun Egba	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	f	t	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	["Olu landing", "Ibeshe Palace", "Elegushi", "Police", "Koko beach", "Power line", "Ibasa", "Baba Shino", "Second Rainbow Landing"]	Olu landing, Ibeshe Palace, Elegushi, Police, Koko beach, Power line, Ibasa, Baba Shino, Second Rainbow Landing	The route gets the most traffic on weekends because of the beach houses on the Ibese shores, the price also increases on weekends by 500naira due to increase in demand	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	applied
77	68	2026-02-18 23:21:08.232	Ikare town landing	Ojo market waterside	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	t	f	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	["Iyagbe"]	Iyagbe	Ojo town landing as the same similarities as Ojo Palace	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	applied
21	19	2026-02-09 11:11:38.152	Liverpool (Apapa)	Boundary (Apapa)	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	8	200	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		About 30-seater boats	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	applied
16	14	2026-02-09 08:47:47.182	Allens Unit/Alex Apapa	Sagbokoji	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	8	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		Boats are also called Wooden boats. They still get water hyacinths but they push it away to make way. This is mostly used by workers 	Mr Ibrahim Owolabi	owolabiibrahim580@gmail.com	applied
19	17	2026-02-09 10:57:15.008	Liverpool (Apapa)	Badore Ferry Terminal	LagFerry/Government: Operated by the government. 	Cowry card	Covered	t	f	45	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Marina/CMS", "Five Cowries/Falomo/Ise Water"]	Liverpool (Apapa), Marina/CMS, Five Cowries/Falomo/Ise Water, Badore Ferry Terminal	In the morning, when the boat is coming from Badore to Liverpool, they don't pick up people at the stops, they only drop off people\n\nIn the evening, when the boat is going to Badore from Liverpool, they only pick people up at those stops and the cost listed for those stop fields are from the location to destination rather than intermediate stops	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	applied
14	12	2026-02-09 08:44:22.291	Allens Unit/Alex Apapa	Manager	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	4	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		Boats are also called Wooden boats. They still get water hyacinths but they push it away to make way	Mr Ibrahim Owolabi	owolabiibrahim580@gmail.com	applied
15	13	2026-02-09 08:46:02.911	Allens Unit/Alex Apapa	KabaKaba	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	4	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		Boats are also called Wooden boats. They still get water hyacinths but they push it away to make way	Mr Ibrahim Owolabi	owolabiibrahim580@gmail.com	applied
18	16	2026-02-09 10:35:32.581	Liverpool (Apapa)	Sagbokoji	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	15	400	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Allens Unit / Alex Apapa"]	Liverpool (Apapa), Allens Unit/Alex Apapa, Sagbokoji	This route is mostly for the fish market. Frequency on market days(Tuesdays, Fridays and Saturdays) are higher	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	applied
27	25	2026-02-09 12:03:26.22	Coconut Landing	Igbo-Elejo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	10	500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Mr Joseph 	None	applied
31	29	2026-02-09 13:47:07.727	Ijegun Egba	Ibasa	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	2	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Mr Damilola	damexsy@gmail.com	applied
25	23	2026-02-09 11:35:37.323	Liverpool (Apapa)	Gbaji Yekeme Jetty	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	45	3500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	applied
36	34	2026-02-10 09:14:56.536	Ibeshe/Thesaurus Ferry Terminal	Five Cowries/Falomo/Ise Water	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Cowry card	Speed boats	f	f	30	2500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		\N	ISHOLA TAIWO OLANREWAJU 	isholataiwoolanrewajutiems@gmail.com	applied
39	34	2026-02-10 09:14:57.336	Ibeshe/Thesaurus Ferry Terminal	Five Cowries/Falomo/Ise Water	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Cowry card	Speed boats	f	f	30	2500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		\N	ISHOLA TAIWO OLANREWAJU 	isholataiwoolanrewajutiems@gmail.com	applied
26	24	2026-02-09 11:37:42.522	Liverpool (Apapa)	Tarkwa Bay	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	t	30	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	applied
30	28	2026-02-09 13:46:10.555	Ijegun Egba	Second Rainbow Landing	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	2	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Mr Damilola	damexsy@gmail.com	applied
29	27	2026-02-09 13:45:27.339	Ijegun Egba	Baba Shino	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	2	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Mr Damilola	damexsy@gmail.com	applied
35	33	2026-02-09 14:52:56.801	Abule Osun	Irede	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	t	f	5	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		\N	Mr olayinka	olayinkamubo26@gmail.com	applied
33	31	2026-02-09 14:46:22.095	Abule Osun	Port Novo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	t	f	120	10000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	["Pashi"]	Abule Osun, Pashi, Port Novo	The stop name is Pashin	Mr Olayinka	olayinkamubo26@gmail.com	applied
47	38	2026-02-10 12:23:52.647	Ijede/Tarzan	Badore Ferry Terminal	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	t	f	10	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		\N	Mr Michael Diyepiriwei	diyemichael@gmail.com	applied
50	41	2026-02-10 13:02:56.74	Oke Ira Nla (Ajah)	Baiyeku	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Speed boats	t	f	7	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Mr Ismail Olowoidiaba	ismailolalekan68@yahoo.com	applied
52	43	2026-02-11 09:25:59.655	Ijon	Ijon Odo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Wooden boats	t	f	5	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		Destination is Ijon Odo	Adeyeye Omotolani	omotolaniadeyeye@gmail.com	applied
53	44	2026-02-11 10:44:11.843	Igando Landing/Ishitu	Totowu Odo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Wooden boats	f	t	7	400	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		Destination is Totowu Odo. Bank transfer is allowed but inform the boat operator before entering the boat	Mr Komolafe Michael	komolafetemitope5555@gmail.com	applied
43	34	2026-02-10 09:15:04.636	Ibeshe/Thesaurus Ferry Terminal	Five Cowries/Falomo/Ise Water	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Cowry card	Speed boats	f	f	30	2500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		\N	ISHOLA TAIWO OLANREWAJU 	isholataiwoolanrewajutiems@gmail.com	applied
44	34	2026-02-10 09:15:04.64	Ibeshe/Thesaurus Ferry Terminal	Five Cowries/Falomo/Ise Water	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Cowry card	Speed boats	f	f	30	2500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		\N	ISHOLA TAIWO OLANREWAJU 	isholataiwoolanrewajutiems@gmail.com	applied
45	36	2026-02-10 09:24:37.357	Ibeshe/Thesaurus Ferry Terminal	Liverpool (Apapa)	LagFerry/Government: Operated by the government. 	Cowry card	Covered	f	f	40	2200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		This route only works during the water hyacinth season 	ISHOLA TAIWO OLANREWAJU 	isholataiwoolanrewajutiems@gmail.com	applied
54	45	2026-02-11 13:11:40.484	Ebute Ojo/Sifax Ferry Terminal	Irewe Ojo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	t	f	37	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		The peak periods happen when they have parties	Mr Pascal	N/A	applied
62	53	2026-02-13 09:42:16.307	Etegbin	Isofin	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	2	100	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Mr Olowoseelu Festus	Remiolusoji7@gmail.com	applied
32	30	2026-02-09 13:53:15.585	Ijegun Egba	Ibeshe Palace	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	f	t	20	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Power line"]	Ijegun Egba, Power line, Ibeshe Palace	On Weekends, there’s beach activity which makes the frequency faster in the afternoons.	Mr Damilola	damexsy@gmail.com	applied
34	32	2026-02-09 14:49:47.834	Abule Osun	Ponton	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	t	f	100	9000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	["Jegba Marina Badagry"]	Abule Osun, Jegba Marina Badagry, Ponton	Destination is ponton 	Mr olayinka	olayinkamubo26@gmail.com	applied
4	4	2026-02-05 17:57:01.106462	Five Cowries/Falomo/Ise Water	Offin, Ikorodu	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash,Bank Transfer	Covered	\N	\N	25	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Five Cowries/Falomo/Ise Water", "Offin Jetty"]	-		Lanre	antholaredo@gmail.com	applied
1	1	2026-02-05 17:57:01.106462	Ebute Ero/Elegbata Jetty	Port Novo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	\N	\N	180	12000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	["Ebute Ero", "Jegba Marina (Badagry)", "Port Novo (Benin Republic)"]	-		Odusami Sheriff Oluwafemi	odusamioluwafemi@gmail.com	applied
56	47	2026-02-11 13:25:15.377	Ebute Ojo/Sifax Ferry Terminal	Ilashe	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana	t	f	45	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Mr Pascal	N/A	applied
59	50	2026-02-12 08:11:04.563	Agboyi Ketu	Agboyi 3	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	2	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		Agboyi 1 should be renamed to Agboyi 3	Otudero Oluwayemisi	None	applied
13	4	2026-02-05 17:57:01.106462	Five Cowries/Falomo/Ise Water	Offin, Ikorodu	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash,Bank Transfer	Covered	\N	\N	25	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Five Cowries/Falomo/Ise Water", "Offin Jetty"]	-		Lanre	antholaredo@gmail.com	applied
8	8	2026-02-05 17:57:01.106462	Ikorodu/Ipakodo Ferry Terminal	Five Cowries/Falomo/Ise Water	LagFerry/Government: Operated by the government.	Cowry card	Catamaran,Speed boats	\N	\N	30	2200	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Ipakodo/Ikorodu Ferry Terminal", "Addax/Sandfill/Maroko Jetty", "Five Cowries/Falomo/Ise Water"]	-		Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	applied
12	13	2026-02-05 17:57:01.106462	Allens Unit/Alex Apapa	KabaKaba	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	f	\N	30	3000	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Ipakodo/Ikorodu Ferry Terminal", "Ebute Ero", "Marina/CMS", "Apapa Flour Mill Jetty"]	-		Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	applied
63	54	2026-02-13 10:37:31.148	Isashi Landing	Iteku	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	f	t	3	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		In the mornings, Iteku to Isashi has high movement and in the evenings, Isashi to Iteku has high movement.	Mr Amodu Falilu	Amoduoluwafemi64@yahoo.com	applied
9	9	2026-02-05 17:57:01.106462	Ikorodu/Ipakodo Ferry Terminal	Apapa Flour Mill	LagFerry/Government: Operated by the government.	Cowry card	Catamaran,Covered	\N	\N	30	2200	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Ipakodo/Ikorodu Ferry Terminal", "Ebute Ero", "Marina/CMS", "Apapa Flour Mill Jetty"]	-		Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	applied
10	10	2026-02-05 17:57:01.106462	Ikorodu/Ipakodo Ferry Terminal	Liverpool (Apapa)	LagFerry/Government: Operated by the government.	Cowry card	Covered,Catamaran	\N	\N	40	2200	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Ipakodo/Ikorodu Ferry Terminal", "Liverpool (Apapa)"]	-		Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	applied
11	11	2026-02-05 17:57:01.106462	Ikorodu/Ipakodo Ferry Terminal	Five Cowries/Falomo/Ise Water	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Speed boats,Covered	t	\N	30	3000	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Ipakodo/Ikorodu Ferry Terminal", "Alluvia Marine Jetty/Afisco Jetty", "Addax/Sandfill/Maroko Jetty", "Five Cowries/Falomo/Ise Water"]	-		Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	applied
46	37	2026-02-10 10:09:51.269	Offin, Ikorodu	Five Cowries/Falomo/Ise Water	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	f	f	25	2700	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	["Lekki Ferry", "Addax / Sandfill / Maroko"]	Offin, Ikorodu, Lekki Ferry, Addax/Sandfill/Maroko, Five Cowries/Falomo/Ise Water	The morning frequency is extremely high on Mondays because people are going to the island but this morning frequency reduces during the week and becomes high again by weekend because people are going back home.\n\nThe ferry route costs 2700 in the mornings and 2200 in the evenings. The boat doesn't pick people up at intermediate stops, only drops them off	Mr Olabinjo Lateef	olabinjolafeef@gmail.com	applied
49	40	2026-02-10 12:27:52.973	Ijede/Tarzan	Five Cowries/Falomo/Ise Water	LagFerry/Government: Operated by the government. 	Cowry card	Covered	t	f	27	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	["Addax / Sandfill / Maroko"]	Ijede/Tarzan, Addax/Sandfill/Maroko, Five Cowries/Falomo/Ise Water	It's a fairly new route so it's not yet popular. Also the boats only drop off when it's an outbound route and thy only pickup when it's an inbound route	Mr Michael Diyepiriwei	diyemichael@gmail.com	applied
55	46	2026-02-11 13:14:26.419	Ebute Ojo/Sifax Ferry Terminal	Ikare town landing	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	t	f	40	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		The peak periods happen when they have parties	Mr Pascal	N/A	applied
57	48	2026-02-11 13:28:20.508	Ebute Ojo/Sifax Ferry Terminal	Agaja	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	f	t	40	1000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Mr Pascal	N/A	applied
58	49	2026-02-11 13:32:23.942	Ebute Ojo/Sifax Ferry Terminal	Marina/CMS	LagFerry/Government: Operated by the government. 	Cowry card, Cash	Covered	f	t	50	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Liverpool (Apapa)"]	Ebute Ojo/Sifax Ferry Terminal, Liverpool (Apapa), Marina/CMS	\N	Mr Pascal	N/A	applied
81	72	2026-02-20 12:12:00.217	Addax/Sandfill/Maroko	Badore Ferry Terminal	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Catamaran, Covered, Banana	t	f	45	1499	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	\N		 N/A	Sikigha Charity	isikighacharity@gmail.com	applied
82	73	2026-02-20 12:13:12.823	Addax/Sandfill/Maroko	Ikorodu/Ipakodo Ferry Terminal	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Catamaran, Covered, Banana	t	f	40	2000	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	\N		 N/A	Sikigha Charity	isikighacharity@gmail.com	applied
83	74	2026-02-20 12:13:58.423	Addax/Sandfill/Maroko	Baiyeku	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Catamaran, Covered, Banana	t	f	45	2000	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	\N		 N/A	Sikigha Charity	isikighacharity@gmail.com	applied
84	75	2026-02-20 12:15:51.263	Apapa Flour Mill	Ikorodu/Ipakodo Ferry Terminal	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Catamaran, Covered, Banana	t	f	45	2499	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Ebute Ero/Elegbata Jetty"]	Ebute Ero/Elegbata Jetty	 N/A	Sikigha Charity	isikighacharity@gmail.com	applied
85	76	2026-02-20 12:17:08.508	Apapa Flour Mill	Marina/CMS	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Catamaran, Covered, Banana	t	f	15	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	\N		 N/A	Sikigha Charity	isikighacharity@gmail.com	applied
86	77	2026-02-20 12:31:01.47	Capital Oil	Mile 2/NIWA	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Catamaran, Covered, Banana	t	f	30	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	\N		 N/A	Sikigha Charity	isikighacharity@gmail.com	applied
98	89	2026-02-25 09:32:40.256	Badore Ferry Terminal	Ijede/Tarzan	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer, Debit card/POS	Covered	f	f	10	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		This route is mostly for workers 	Mr Haruna deji 	Harunadeji05@gmail.com	applied
99	90	2026-02-25 09:35:59.506	Badore Ferry Terminal	Five Cowries/Falomo/Ise Water	LagFerry/Government: Operated by the government. 	Cash, Cowry card	Catamaran, Speed boats	f	f	40	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		This  boat can move twice on Mondays but other weekdays is just once 	Mr Haruna deji 	Harunadeji05@gmail.com	applied
100	91	2026-02-25 09:37:40.224	Badore Ferry Terminal	Gberigbe	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	f	f	15	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		Workers use this route	Mr Haruna deji 	Harunadeji05@gmail.com	applied
101	92	2026-02-25 09:41:51.816	Badore Ferry Terminal	Itomu Jetty	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	f	f	5	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		Although a person can wait on average for 25 minutes for the boat to be filled but if there are 5 passengers then the boat can move 	Mr Haruna deji 	Harunadeji05@gmail.com	applied
103	94	2026-02-25 10:04:53.357	Itomu Jetty	Kabiyesi itomu jetty	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	2	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		This is a route used for crossing...about 30m long 	Fisayo 	Fisayo@publictech.studio	applied
104	95	2026-02-25 12:42:07.429	Epe Ayetoro Jetty	Ondo (Ipare)	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	t	f	150	8000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		The boat leaves once a day and returns the next morning and gets to  Epe by 11. There could be stops but the officers aren't aware	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com 	applied
105	96	2026-02-25 12:43:55.983	Epe Ayetoro Jetty	Ogun (Iwopin)	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	t	f	110	3500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		The boat leaves once a day and returns the next morning also and  gets to  Epe by 12pm. There could be stops but the officers aren't aware	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com 	applied
106	97	2026-02-25 12:45:39.091	Epe Ayetoro Jetty	Abomiti-Nla Epe	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	t	f	60	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		The boat leaves once a day and returns the next morning also and  gets to  Epe by 12pm.	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com 	applied
107	98	2026-02-25 12:48:55.259	Epe Ayetoro Jetty	Eyin Osa	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	20	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com 	applied
112	103	2026-02-25 18:21:35.696	Gberigbe	Marina/CMS	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	65	3498	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Ebute Ero/Elegbata Jetty"]	Ebute Ero/Elegbata Jetty	\N	Sikigha Charity	isikighacharity@gmail.com	applied
116	107	2026-02-25 18:41:11.417	Egbin	Marina/CMS	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	65	3500	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Addax/Sandfill/Maroko"]	Addax/Sandfill/Maroko	\N	Sikigha Charity	isikighacharity@gmail.com	applied
117	108	2026-02-25 19:22:19.084	Kirikiri	Marina/CMS	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	40	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Liverpool (Apapa)"]	Liverpool (Apapa)	\N	Sikigha Charity	isikighacharity@gmail.com	applied
118	108	2026-02-25 20:54:40.991	Kirikiri	Marina/CMS	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	40	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Liverpool (Apapa)"]	Liverpool (Apapa)	\N	Sikigha Charity	isikighacharity@gmail.com	applied
119	109	2026-02-25 20:57:55.139	Kirikiri	Mile 2/NIWA	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	20	1199	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	\N		stopovers along thia route are ijegun egba, coconut landing and ibasa but they arent common.	Sikigha Charity	isikighacharity@gmail.com	applied
120	110	2026-02-27 08:40:20.896	Mile 2/NIWA	Port Novo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	t	f	150	12000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Owode"]	Owode	Apparently, Owode and Pashi are regarded as the same place because of proximity.	Israel Ekundayo	israelekundayo@gmail.com	applied
121	111	2026-02-27 09:42:15.519	Ojo market waterside	Ilashe	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	t	f	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Iyagbe"]	Iyagbe	\N	Israel Ekundayo	israelekundayo@gmail.com	applied
122	112	2026-02-27 09:51:54.484	Ojo market waterside	Ibese	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	t	f	30	2000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
123	113	2026-02-27 09:55:26.927	Ojo market waterside	Ikare town landing	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat, Wooden boats	t	f	25	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
125	115	2026-02-27 10:15:22.948	Ojo market waterside	Agaja	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	t	f	15	1000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
126	116	2026-02-27 11:02:08.795	Kirikiri	Port Novo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	360	12000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	["Jegba Marina Badagry"]	Jegba Marina Badagry	This route form covers for jegba marina badagry and port novo as often times,there are usually not even paasengers for jegba marina so they merge them up with pople heading to port novo, they do a stopover at jegba marina,pick up likely passengers for port novo too as well 	Sikigha Charity	isikighacharity@gmail.com	applied
131	121	2026-02-27 11:36:31.736	Capital Oil	Kirikiri	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	35	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Mile 2/NIWA"]	Mile 2/NIWA	\N	Sikigha Charity	isikighacharity@gmail.com	applied
132	122	2026-02-27 11:40:32.946	Capital Oil	Liverpool (Apapa)	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	45	2498	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Sagbokoji"]	Sagbokoji	\N	Sikigha Charity	isikighacharity@gmail.com	applied
133	122	2026-02-27 11:40:55.555	Capital Oil	Liverpool (Apapa)	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	45	2498	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Sagbokoji"]	Sagbokoji	\N	Sikigha Charity	isikighacharity@gmail.com	applied
134	123	2026-02-27 12:04:26.134	Kirikiri	Ijegun Egba	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	25	1199	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	\N		\N	Sikigha Charity	isikighacharity@gmail.com	applied
135	124	2026-02-27 12:18:06.783	Marina/CMS	Ikorodu/Ipakodo Ferry Terminal	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	40	2500	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Ebute Ero/Elegbata Jetty"]	Ebute Ero/Elegbata Jetty	\N	Sikigha Charity	isikighacharity@gmail.com	applied
136	125	2026-02-27 12:21:42.564	Marina/CMS	Tarkwa Bay	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	t	f	19	1999	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Ogogoro Village"]	Ogogoro Village	the frequency of passengers cannot be streamlined as much as possible cause different days and demand varies. peak hours are early afternoons till eaely evenings.	Sikigha Charity	isikighacharity@gmail.com	applied
137	126	2026-02-27 12:24:43.594	Marina/CMS	Port Novo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	420	14000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	["Jegba Marina Badagry"]	Jegba Marina Badagry	\N	Sikigha Charity	isikighacharity@gmail.com	applied
139	128	2026-02-27 12:33:35.19	Marina/CMS	Liverpool (Apapa)	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	30	1999	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		this route is currently not active i think due to an internal situation but if it were active that would be the information needed.	Sikigha Charity	isikighacharity@gmail.com	applied
140	129	2026-02-27 12:35:25.033	Marina/CMS	Sagbokoji	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	30	998	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		\N	Sikigha Charity	isikighacharity@gmail.com	applied
142	131	2026-02-27 15:04:34.138	Second Badagry	Number 1A Waterside	Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	t	f	7	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		They work on public holidays. They close by 10:00 pm, but they give a grace of 15 minutes to passengers. No life jackets worn by passengers. Passengers stand in these boats. They are under The Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON). Peak Times: 5am - 9am, 5pm - 7pm.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
143	132	2026-02-27 15:05:21.084	Mogaji (Ajegunle)	Number 1A Waterside	Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	t	f	7	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		They work on public holidays. They close by 10:00 pm, but they give a grace of 15 minutes to passengers. No life jackets worn by passengers. Passengers stand in these boats. They are under The Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON). Peak Times: 5am - 9am, 5pm - 7pm.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
144	76	2026-02-27 15:17:35.065	Apapa Flour Mill	Marina/CMS	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Debit card/POS	Catamaran	t	f	10	700	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		Fibre boats that are not managed by Texas Connection Ferries (Monday, Wednesday, and Friday) and Sea Coach (Thursday and Mondays) operate on weekends and charge the same 700 naira. Every week, the manner of operation changes. Sea coach works twice if TCF works three times, and vice versa. On holidays, they don't work with the exception of fibre boats not under their management.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
147	135	2026-02-27 15:24:57.243	Number 2 (Apapa) Waterside	Number 2 (Ajegunle) Waterside	Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	t	f	5	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		They work on public holidays. They close by 10:00 pm, but they give a grace of 15 minutes to passengers. No life jackets worn by passengers. Passengers stand in these boats. They are under The Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON).	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
148	136	2026-02-27 15:25:13.709	Marina/CMS	Badore Ferry Terminal	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	60	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	["Five Cowries/Falomo/Ise Water"]	Five Cowries/Falomo/Ise Water	this route operates on a peak period basis and sometimes charter. i think there isnt enough publicity on this route so on some days, it would be a boat or 2 that would be fully loaded for badore, on other days, none at all. 	Sikigha Charity	isikighacharity@gmail.com	applied
150	138	2026-02-27 15:35:41.799	Boundary (Apapa)/Number 3 (Apapa) Waterside	Number 3 (Ajegunle) Waterside	Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	t	f	5	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		They are open on public holidays. Passengers are given a 15-minute grace period before they close at 10:00 p.m. By 11:00 p.m., which is far later than the official closure hour, you could also be able to take a boat to the other side. No life jackets are being worn by the passengers. Passengers are standing in these boats. Their parent organization is the Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON). Although they open at 5:00 am, you can catch boats about here around 4:30 am.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
152	140	2026-02-27 21:25:24.138	First Gate (Tin Can Island)	IKO/Temidire	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	f	t	5	150	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		8 entities under NIWA's authority control this place. On weekends, they close by 9:00 pm	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
154	142	2026-02-27 21:28:29.233	Number 1 (Ajegunle) Waterside	Number 1 (Apapa) Waterside	Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	t	t	5	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		They work on public holidays. They close by 10:00 pm, but they give a grace of 15 minutes to passengers. No life jackets worn by passengers. Passengers stand in these boats. They are under The Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON).	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
156	144	2026-02-27 21:57:52.43	Mile 2/NIWA	Port Novo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	t	f	150	12000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Pashi"]	Pashi	\N	Israel Ekundayo	israelekundayo@gmail.com	applied
158	142	2026-02-27 22:04:14.919	Number 1 (Ajegunle) Waterside	Number 1 (Apapa) Waterside	Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	t	t	5	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		They work on public holidays. They close by 10:00 pm, but they give a grace of 15 minutes to passengers. No life jackets worn by passengers. Passengers stand in these boats. They are under The Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON).	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
162	148	2026-02-28 00:25:18.503	Ibese	Ojo market waterside	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana	t	f	45	2000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	["Ikare palace", "Ikare town landing", "Ilashe", "Iyagbe"]	Ikare palace, Ikare town landing, Ilashe, Iyagbe	this route is usually not busy, somedays, they might not be any boat going from ibese to ojo, the route is mostly active on market days, or when activities are taking place in villages along the route. 	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	applied
163	149	2026-02-28 14:41:07.223	Itomoro	Agojedo/Agbejedo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	t	t	3	100	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		Most boat operators might refuse to carry you as it is approximately a five minute walk from Itomoro. They would encourage you to trek it.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
165	126	2026-02-28 15:56:43.025	Marina/CMS	Port Novo	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	t	f	180	11000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Jegba Marina Badagry"]	Jegba Marina Badagry	\N	Israel Ekundayo	israelekundayo@gmail.com	applied
170	129	2026-02-28 16:26:03.606	Marina/CMS	Sagbokoji	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat, Wooden boats, Covered	t	t	15	700	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
171	154	2026-02-28 16:31:06.07	Marina/CMS	Ogogoro Village	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	t	10	1000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
172	155	2026-03-03 08:48:57.96	Egbin	Marina/CMS	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	t	f	60	3000	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	["Ebute Ero/Elegbata Jetty"]	Ebute Ero/Elegbata Jetty	\N	Charity Sikigha	isikighacharity@gmail.com	applied
173	156	2026-03-03 09:15:26.92	Port Novo	Ebute Ero/Elegbata Jetty	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	t	f	180	7000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Gbaji Yekeme Jetty", "Abule Osun", "Kirikiri", "Mile 2/NIWA", "Liverpool (Apapa)", "Marina/CMS"]	Gbaji Yekeme Jetty, Abule Osun, Kirikiri, Mile 2/NIWA, Liverpool (Apapa), Marina/CMS	The bulk of the time duration is from port novo to gbaji due to checkpoints 	Officer Samuel	Samuelolorunwamautin@yahoo.com	applied
174	157	2026-03-03 09:16:01.543	Farasimeh	Ebute Ero/Elegbata Jetty	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	t	f	180	7000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Gbaji Yekeme Jetty", "Abule Osun", "Kirikiri", "Mile 2/NIWA", "Liverpool (Apapa)", "Marina/CMS"]	Gbaji Yekeme Jetty, Abule Osun, Kirikiri, Mile 2/NIWA, Liverpool (Apapa), Marina/CMS	The bulk of the time duration is from port novo to gbaji due to checkpoints. Farisimeh is the port novo side of Nigeria 	Officer Samuel	Samuelolorunwamautin@yahoo.com	applied
175	158	2026-03-03 09:48:16.751	Iya Afin Jetty	Izigi	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat, Wooden boats	t	f	30	500	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		During the water hyacinth season, they move to another waterside to board- it’s also Iya Afin. Peak period is only during the festive period 	Mr Kadeem Fayemi	Kazeemfayemi0@gmail.com	applied
176	73	2026-03-04 00:35:16.999	Addax/Sandfill/Maroko	Ikorodu/Ipakodo Ferry Terminal	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	t	f	35	2500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
177	159	2026-03-04 00:36:25.377	Addax/Sandfill/Maroko	Ibeshe/Thesaurus Ferry Terminal	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	t	f	25	2000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
178	74	2026-03-04 00:37:29.881	Addax/Sandfill/Maroko	Baiyeku	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	t	f	30	2500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
179	160	2026-03-04 00:38:42.648	Addax/Sandfill/Maroko	Offin, Ikorodu	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	t	f	25	2300	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
180	161	2026-03-04 00:39:44.239	Addax/Sandfill/Maroko	Ijede/Tarzan	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	t	f	35	2500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
181	162	2026-03-05 03:21:16.052	Igbo Elejo	Liverpool (Apapa)	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats, Fibre boat	t	f	15	500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	["Itu Agan/Itun Agan"]	Itu Agan/Itun Agan	\N	Israel Ekundayo	israelekundayo@gmail.com	applied
182	163	2026-03-05 03:24:07.114	Igbo Elejo	Isoda	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats, Fibre boat	t	f	5	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
183	164	2026-03-05 15:08:16.184	Isoda	Liverpool (Apapa)	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	t	f	35	500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Igbo Elejo", "Itu Agan/Itun Agan"]	Igbo Elejo, Itu Agan/Itun Agan	\N	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
184	165	2026-03-06 14:12:38.091	Ilutuntun	Isoda	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	t	f	5	200	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
185	166	2026-03-06 15:05:12.926	Itomoro	Liverpool (Apapa)	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	t	f	35	800	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	["Agojedo/Agbejedo", "Jemuje", "Ilutuntun", "Igbo Elejo", "Itu Agan/Itun Agan", "Liverpool (Apapa)"]	Agojedo/Agbejedo, Jemuje, Ilutuntun, Igbo Elejo, Itu Agan/Itun Agan, Liverpool (Apapa)	\N	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	applied
187	168	2026-03-06 21:23:05.205	Irewe Ojo	Ojo market waterside	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat, Wooden boats	t	f	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N		\N	Israel Ekundayo	israelekundayo@gmail.com	applied
190	23	2026-03-13 12:56:23.033	Liverpool (Apapa)	Gbaji Yekeme Jetty	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	t	f	45	3500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "The entire day", "203": "10", "211": "57", "214": "Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)", "218": "45", "221": "3500", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Saturday", "235": "No", "236": "Yes", "326": ["Cash"], "327": ["Banana"], "344": "No", "345": "Yes", "346": "Yes", "347": "No", "sunday_hours": [], "weekday_hours": [{"endTime": "", "startTime": "08:00", "boatsPerDay": "1", "isOneTimeOnly": "Yes", "evening_service": false, "morning_service": true, "frequencyMinutes": "60"}, {"endTime": "", "startTime": "17:15", "boatsPerDay": "1", "isOneTimeOnly": "Yes", "evening_service": true, "morning_service": false, "frequencyMinutes": "60"}], "saturday_hours": []}	Liverpool (Apapa), Gbaji Yekeme Jetty	\N	Fisayo 	fisayo@publictech.studio	applied
189	23	2026-03-13 12:36:39.979	Liverpool (Apapa)	Gbaji Yekeme Jetty	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	f	f	45	3500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "The entire day", "203": "10", "211": "57", "214": "Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)", "218": "45", "221": "3500", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Friday", "235": "No", "326": ["Cash"], "327": ["Banana"], "344": "No", "345": "Yes", "346": "Yes", "347": "No", "sunday_hours": [], "weekday_hours": [{"endTime": "", "startTime": "08:00", "boatsPerDay": "1", "isOneTimeOnly": "Yes", "evening_service": false, "morning_service": true, "frequencyMinutes": "60"}, {"endTime": "", "startTime": "17:15", "boatsPerDay": "1", "isOneTimeOnly": "Yes", "evening_service": true, "morning_service": false, "frequencyMinutes": "60"}], "saturday_hours": []}	Liverpool (Apapa), Gbaji Yekeme Jetty	\N	Fisayo 	fisayo@publictech.studio	rejected
191	23	2026-03-13 12:58:01.754	Liverpool (Apapa)	Gbaji Yekeme Jetty	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	t	f	45	3500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "The entire day", "203": "10", "211": "57", "214": "Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)", "218": "45", "221": "3500", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Saturday", "235": "No", "236": "Yes", "326": ["Cash"], "327": ["Banana"], "344": "No", "345": "Yes", "346": "Yes", "347": "No", "sunday_hours": [], "weekday_hours": [{"endTime": "", "startTime": "08:00", "boatsPerDay": "1", "isOneTimeOnly": "Yes", "evening_service": false, "morning_service": true, "frequencyMinutes": "60"}, {"endTime": "", "startTime": "17:15", "boatsPerDay": "1", "isOneTimeOnly": "Yes", "evening_service": true, "morning_service": false, "frequencyMinutes": "60"}], "saturday_hours": []}	Liverpool (Apapa), Gbaji Yekeme Jetty	\N	Fisayo 	fisayo@publictech.studio	applied
192	170	2026-03-24 12:09:58.787	Fiki Marine	Tarkwa Bay	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer, Debit card/POS	Catamaran	f	t	30	15000	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	{"192": "Hannah Kates", "197": "hannah@publictech.studio", "203": "54", "211": "130", "214": "Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)", "216": "No", "218": "30", "221": "15000", "230": "Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Weekends (Saturday & Sunday)", "238": "Yes", "246": "Ticket prices are round-trip.", "326": ["Cash", "Bank Transfer", "Debit card/POS"], "327": ["Catamaran"], "331": "The entire day", "348": "Yes", "349": "Yes", "350": "Yes", "351": "Yes", "sunday_hours": [], "weekday_hours": [], "saturday_hours": [{"endTime": "18:00", "startTime": "11:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": true, "morning_service": true, "frequencyMinutes": "60"}]}	Fiki Marine, Tarkwa Bay	Ticket prices are round-trip.	Hannah Kates	hannah@publictech.studio	applied
193	171	2026-03-30 15:10:34.677	Ikorodu/Ipakodo Ferry Terminal	Five Cowries/Falomo/Ise Water	LagFerry/Government: Operated by the government. 	Cowry card	Catamaran	f	f	9999	1	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "Mornings alone", "203": "3", "211": "2", "214": "LagFerry/Government: Operated by the government. ", "218": "9999", "221": "1", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "Yes, this route gets disrupted and doesn't work during the water hyacinth season", "234": "Monday - Friday", "235": "Yes", "243": "9999", "245": "1", "246": "future omi eko", "326": ["Cowry card"], "327": ["Catamaran"], "344": "Yes", "345": "No", "346": "No", "347": "Yes", "sunday_hours": [], "weekday_hours": [{"endTime": "02:00", "startTime": "01:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": false, "morning_service": true, "frequencyMinutes": "35"}], "saturday_hours": [], "stop_weekday_0_cost": "1", "stop_weekday_0_name": "96", "stop_weekday_0_time": "9999", "stop_weekday_1_cost": "1", "stop_weekday_1_name": "7", "stop_weekday_1_time": "9999", "stop_weekday_0_always": "Yes", "stop_weekday_1_always": "Yes", "stop_weekday_0_isNextDest": "No", "stop_weekday_1_isNextDest": "Yes"}	Ikorodu/Ipakodo Ferry Terminal, Lekki Ferry, Addax/Sandfill/Maroko, Five Cowries/Falomo/Ise Water	future omi eko	Fisayo 	fisayo@publictech.studio	applied
194	172	2026-03-30 15:14:50.542	Baiyeku	Five Cowries/Falomo/Ise Water	LagFerry/Government: Operated by the government. 	Cowry card	Catamaran	f	f	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "Mornings alone", "203": "31", "211": "2", "214": "LagFerry/Government: Operated by the government. ", "218": "9999", "221": "1", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Friday", "235": "Yes", "243": "9999", "245": "1", "246": "future omi eko", "326": ["Cowry card"], "327": ["Catamaran"], "344": "Yes", "345": "No", "346": "No", "347": "Yes", "sunday_hours": [], "weekday_hours": [{"endTime": "02:00", "startTime": "01:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": false, "morning_service": true, "frequencyMinutes": "35"}], "saturday_hours": [], "stop_weekday_0_cost": "1", "stop_weekday_0_name": "96", "stop_weekday_0_time": "9999", "stop_weekday_1_cost": "1", "stop_weekday_1_name": "7", "stop_weekday_1_time": "9999", "stop_weekday_0_always": "Yes", "stop_weekday_1_always": "Yes", "stop_weekday_0_isNextDest": "No", "stop_weekday_1_isNextDest": "Yes"}	Baiyeku, Lekki Ferry, Addax/Sandfill/Maroko, Five Cowries/Falomo/Ise Water	future omi eko	Fisayo 	fisayo@publictech.studio	applied
195	173	2026-03-30 15:17:21.935	Ikorodu/Ipakodo Ferry Terminal	Liverpool (Apapa)	LagFerry/Government: Operated by the government. 	Cowry card	Catamaran	f	f	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "Mornings alone", "203": "3", "211": "10", "214": "LagFerry/Government: Operated by the government. ", "218": "9999", "221": "1", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Friday", "235": "Yes", "243": "9999", "245": "1", "246": "future omi eko", "326": ["Cowry card"], "327": ["Catamaran"], "344": "Yes", "345": "No", "346": "No", "347": "Yes", "sunday_hours": [], "weekday_hours": [{"endTime": "02:00", "startTime": "01:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": false, "morning_service": true, "frequencyMinutes": "35"}], "saturday_hours": [], "stop_weekday_0_cost": "1", "stop_weekday_0_name": "5", "stop_weekday_0_time": "9999", "stop_weekday_1_cost": "1", "stop_weekday_1_name": "7", "stop_weekday_1_time": "9999", "stop_weekday_0_always": "Yes", "stop_weekday_1_always": "Yes", "stop_weekday_0_isNextDest": "Yes", "stop_weekday_1_isNextDest": "Yes"}	Ikorodu/Ipakodo Ferry Terminal, Apapa Flour Mill, Addax/Sandfill/Maroko, Liverpool (Apapa)	future omi eko	Fisayo 	fisayo@publictech.studio	applied
196	174	2026-03-30 15:20:18.633	Ebute Ero/Elegbata Jetty	Marina/CMS	LagFerry/Government: Operated by the government. 	Cowry card	Catamaran	f	f	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "Mornings alone", "203": "1", "211": "6", "214": "LagFerry/Government: Operated by the government. ", "218": "9999", "221": "1", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Friday", "235": "No", "243": "9999", "245": "1", "246": "future omi eko", "326": ["Cowry card"], "327": ["Catamaran"], "344": "Yes", "345": "Yes", "346": "Yes", "347": "Yes", "sunday_hours": [], "weekday_hours": [{"endTime": "02:00", "startTime": "01:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": false, "morning_service": true, "frequencyMinutes": "35"}], "saturday_hours": [], "stop_weekday_0_cost": "1", "stop_weekday_0_name": "5", "stop_weekday_0_time": "9999", "stop_weekday_1_cost": "1", "stop_weekday_1_name": "7", "stop_weekday_1_time": "9999", "stop_weekday_0_always": "Yes", "stop_weekday_1_always": "Yes", "stop_weekday_0_isNextDest": "Yes", "stop_weekday_1_isNextDest": "Yes"}	Ebute Ero/Elegbata Jetty, Marina/CMS	future omi eko	Fisayo 	fisayo@publictech.studio	applied
197	175	2026-03-30 15:22:44.266	Oworonsoki	Five Cowries/Falomo/Ise Water	LagFerry/Government: Operated by the government. 	Cowry card	Catamaran	f	f	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "Mornings alone", "203": "118", "211": "2", "214": "LagFerry/Government: Operated by the government. ", "218": "9999", "221": "1", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Friday", "235": "Yes", "243": "9999", "245": "1", "246": "future omi eko", "326": ["Cowry card"], "327": ["Catamaran"], "344": "Yes", "345": "No", "346": "No", "347": "Yes", "sunday_hours": [], "weekday_hours": [{"endTime": "02:00", "startTime": "01:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": false, "morning_service": true, "frequencyMinutes": "35"}], "saturday_hours": [], "stop_weekday_0_cost": "1", "stop_weekday_0_name": "32", "stop_weekday_0_time": "9999", "stop_weekday_1_cost": "1", "stop_weekday_1_name": "7", "stop_weekday_1_time": "9999", "stop_weekday_2_cost": "1", "stop_weekday_2_name": "1", "stop_weekday_2_time": "9999", "stop_weekday_3_cost": "1", "stop_weekday_3_name": "5", "stop_weekday_3_time": "9999", "stop_weekday_4_cost": "1", "stop_weekday_4_name": "6", "stop_weekday_4_time": "9999", "stop_weekday_0_always": "Yes", "stop_weekday_1_always": "Yes", "stop_weekday_2_always": "Yes", "stop_weekday_3_always": "Yes", "stop_weekday_4_always": "Yes", "stop_weekday_0_isNextDest": "No", "stop_weekday_1_isNextDest": "Yes", "stop_weekday_2_isNextDest": "No", "stop_weekday_3_isNextDest": "No", "stop_weekday_4_isNextDest": "Yes"}	Oworonsoki, Bariga Waterfront, Addax/Sandfill/Maroko, Ebute Ero/Elegbata Jetty, Apapa Flour Mill, Marina/CMS, Five Cowries/Falomo/Ise Water	future omi eko	Fisayo 	fisayo@publictech.studio	applied
198	176	2026-03-30 15:25:49.586	Marina/CMS	Ebute Ojo/Sifax Ferry Terminal	LagFerry/Government: Operated by the government. 	Cowry card	Catamaran	f	f	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "Mornings alone", "203": "6", "211": "9", "214": "LagFerry/Government: Operated by the government. ", "218": "9999", "221": "1", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Friday", "235": "Yes", "243": "9999", "245": "1", "246": "future omi eko", "326": ["Cowry card"], "327": ["Catamaran"], "344": "No", "345": "Yes", "346": "Yes", "347": "No", "sunday_hours": [], "weekday_hours": [{"endTime": "02:00", "startTime": "01:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": false, "morning_service": true, "frequencyMinutes": "35"}], "saturday_hours": [], "stop_weekday_0_cost": "1", "stop_weekday_0_name": "27", "stop_weekday_0_time": "9999", "stop_weekday_1_cost": "1", "stop_weekday_1_name": "7", "stop_weekday_1_time": "9999", "stop_weekday_2_cost": "1", "stop_weekday_2_name": "10", "stop_weekday_2_time": "9999", "stop_weekday_3_cost": "1", "stop_weekday_3_name": "55", "stop_weekday_3_time": "9999", "stop_weekday_4_cost": "1", "stop_weekday_4_name": "59", "stop_weekday_4_time": "9999", "stop_weekday_0_always": "Yes", "stop_weekday_1_always": "Yes", "stop_weekday_2_always": "Yes", "stop_weekday_3_always": "Yes", "stop_weekday_4_always": "Yes", "stop_weekday_0_isNextDest": "No", "stop_weekday_1_isNextDest": "Yes", "stop_weekday_2_isNextDest": "No", "stop_weekday_3_isNextDest": "No", "stop_weekday_4_isNextDest": "Yes"}	Marina/CMS, Allens Unit/Alex Apapa, Addax/Sandfill/Maroko, Liverpool (Apapa), First Gate (Tin Can Island), Ibasa, Ebute Ojo/Sifax Ferry Terminal	future omi eko	Fisayo 	fisayo@publictech.studio	applied
201	178	2026-03-30 15:33:54.996	Liverpool (Apapa)	Capital Oil/FESTAC	LagFerry/Government: Operated by the government. 	Cowry card	Covered	f	f	9996	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "Mornings alone", "203": "10", "211": "36", "214": "LagFerry/Government: Operated by the government. ", "218": "9996", "221": "1", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Friday", "235": "Yes", "243": "9999", "245": "1", "246": "future omi eko", "326": ["Cowry card"], "327": ["Covered"], "344": "Yes", "345": "Yes", "346": "Yes", "347": "Yes", "sunday_hours": [], "weekday_hours": [{"endTime": "02:00", "startTime": "01:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": false, "morning_service": true, "frequencyMinutes": "35"}], "saturday_hours": [], "stop_weekday_0_cost": "1", "stop_weekday_0_name": "38", "stop_weekday_0_time": "9999", "stop_weekday_1_cost": "1", "stop_weekday_1_name": "101", "stop_weekday_1_time": "9999", "stop_weekday_0_always": "Yes", "stop_weekday_1_always": "Yes", "stop_weekday_0_isNextDest": "No", "stop_weekday_1_isNextDest": "Yes"}	Liverpool (Apapa), Coconut Landing, Mile 2/NIWA, Capital Oil/FESTAC	future omi eko	Fisayo 	fisayo@publictech.studio	applied
202	179	2026-04-07 16:03:57.705	Agboyi Ketu	Oko Agbon	Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	t	f	20	100	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "The entire day", "203": "23", "211": "22", "214": "Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)", "218": "20", "221": "100", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Sunday", "235": "Yes", "236": "Yes", "243": "5", "245": "100", "326": ["Cash"], "327": ["Wooden boats"], "344": "Yes", "345": "Yes", "346": "Yes", "347": "Yes", "sunday_hours": [], "weekday_hours": [{"endTime": "18:30", "startTime": "05:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": true, "morning_service": true, "frequencyMinutes": "15"}], "saturday_hours": [], "stop_weekday_0_cost": "50", "stop_weekday_0_name": "21", "stop_weekday_0_time": "5", "stop_weekday_1_cost": "100", "stop_weekday_1_name": "112", "stop_weekday_1_time": "10", "stop_weekday_0_always": "Depends on the passengers' demands", "stop_weekday_1_always": "Depends on the passengers' demands", "stop_weekday_0_isNextDest": "No", "stop_weekday_1_isNextDest": "Yes"}	Agboyi Ketu, Agboyi 2, Agboyi 1, Oko Agbon	\N	Fisayo 	fisayo@publictech.studio	applied
203	180	2026-04-07 16:18:53.732	Etegbin	Egan Landing	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	t	f	5	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "The entire day", "203": "51", "211": "41", "214": "Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)", "218": "5", "221": "300", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Sunday", "235": "No", "236": "Yes", "326": ["Cash"], "327": ["Wooden boats"], "344": "Yes", "345": "Yes", "346": "Yes", "347": "Yes", "sunday_hours": [], "weekday_hours": [{"endTime": "12:00", "startTime": "06:30", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": true, "morning_service": true, "frequencyMinutes": "10"}, {"endTime": "14:00", "startTime": "12:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": true, "morning_service": false, "frequencyMinutes": "20"}, {"endTime": "18:30", "startTime": "14:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": true, "morning_service": false, "frequencyMinutes": "10"}], "saturday_hours": []}	Etegbin, Egan Landing	\N	Fisayo 	fisayo@publictech.studio	applied
204	32	2026-04-08 08:46:35.111	Abule Osun	Ponton	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	f	f	130	15000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	{"192": "Fisayo ", "197": "fisayo@publictech.studio", "202": "The entire day", "203": "18", "211": "140", "214": "Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)", "218": "130", "221": "15000", "230": "All boats are suspended.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Friday", "235": "Yes", "243": "100", "245": "9000", "246": "will this get pushed?", "326": ["Cash"], "327": ["Banana"], "344": "No", "345": "No", "346": "Yes", "347": "No", "sunday_hours": [], "weekday_hours": [{"endTime": "", "startTime": "18:30", "boatsPerDay": "1", "isOneTimeOnly": "Yes", "evening_service": true, "morning_service": false, "frequencyMinutes": "120"}], "saturday_hours": [], "stop_weekday_0_cost": "1000", "stop_weekday_0_name": "13", "stop_weekday_0_time": "10", "stop_weekday_0_always": "Yes", "stop_weekday_0_isNextDest": "Yes"}	Abule Osun, Jegba Marina Badagry/Commando Jetty, Ponton	will this get pushed?	Fisayo 	fisayo@publictech.studio	rejected
205	181	2026-04-21 10:10:28.935	Imore Waterside	Imore Community	Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	t	f	8	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	{"192": "Fisayo Balogun", "197": "fisayo@publictech.studio", "202": "The entire day", "203": "79", "211": "222", "214": "Informal Commercial: Operated by unlicensed operators(NOT under the jurisdiction/licensed by LASWA/NIWA)", "218": "8", "221": "300", "230": "All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.", "231": "No, this route doesn't get disrupted and still works during the water hyacinth season", "234": "Monday - Sunday", "235": "No", "236": "Yes", "326": ["Cash"], "327": ["Wooden boats"], "344": "Yes", "345": "Yes", "346": "Yes", "347": "Yes", "sunday_hours": [], "weekday_hours": [{"endTime": "10:00", "startTime": "06:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": false, "morning_service": true, "frequencyMinutes": "20"}, {"endTime": "14:00", "startTime": "10:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": true, "morning_service": true, "frequencyMinutes": "35"}, {"endTime": "16:00", "startTime": "14:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": true, "morning_service": false, "frequencyMinutes": "25"}, {"endTime": "18:00", "startTime": "16:00", "boatsPerDay": "", "isOneTimeOnly": "No", "evening_service": true, "morning_service": false, "frequencyMinutes": "20"}], "saturday_hours": []}	Imore Waterside, Imore Community	\N	Fisayo Balogun	fisayo@publictech.studio	applied
\.


--
-- Data for Name: routes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.routes (route_id, modified_at, operator, payment_options, boat_types, weekend_equals_weekday_schedule, saturday_equals_sunday_schedule, total_base_duration, total_base_cost, hyacinth_season_disruption, rain, geom, route_stops, stop_names, additional_notes, contact_name, contact_email, origin, destination, requires_review, omi_eko) FROM stdin;
131	2026-02-27 15:04:34.138	Informal Commercial: Operated by unlicensed operators (NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	Yes	\N	7	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.348632701587175 6.441002654802053 0, 3.34927464391201 6.442618578585259 0)	f	[124, 104]	They work on public holidays. They close by 10:00 pm, but they give a grace of 15 minutes to passengers. No life jackets worn by passengers. Passengers stand in these boats. They are under The Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON). Peak Times: 5am - 9am, 5pm - 7pm.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	124	104	f	f
27	2026-02-09 13:45:27.339	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	2	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.258695694086362 6.427831511626604 0, 3.257496058473913 6.424669519971173 0)	f	[70, 30]	\N	Mr Damilola	damexsy@gmail.com	70	30	f	f
25	2026-02-09 12:03:26.22	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	10	500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3358558 6.4379208 0, 3.3337635067404 6.436848659134332 0, 3.332813163730622 6.436326902187787 0, 3.332160967547441 6.435711974357931 0, 3.331938911398069 6.433122031204133 0, 3.3345191161320713 6.427478038731522 0)	f	[38, 67]	\N	Mr Joseph 	None	38	67	f	t
8	2026-01-13 00:00:00	LagFerry/Government: Operated by the government	Cowry card	Catamaran,Speed boats	\N	\N	30	2200	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4862304 6.601832 0, 3.478228496825832 6.584248038327353 0, 3.4569869615537536 6.545684635523536 0, 3.4648538004672886 6.4646156990758605 0, 3.465193012934924 6.457076872637717 0, 3.465374789104149 6.455239964720791 0, 3.4656442305715127 6.453693420659534 0, 3.4660644819424045 6.452624029445177 0, 3.4661861514235768 6.451809985414929 0, 3.4658841052939273 6.4511120883416515 0, 3.4636824129728243 6.449881435433807 0, 3.462310352929126 6.449784133147343 0, 3.4598271842834762 6.449982294866626 0, 3.4580453380262925 6.450136901329213 0, 3.456446096600939 6.450405869405844 0, 3.455451968688856 6.45054086180561 0, 3.4542739666005366 6.4504101963342215 0, 3.4534333458584756 6.450039599279447 0, 3.4531316251712507 6.449636655130944 0, 3.453073181638116 6.448325046638855 0, 3.4533534504839283 6.444360299043453 0, 3.453163694796562 6.442226121022745 0, 3.452852493984118 6.439899795560487 0, 3.449508938510678 6.437405975143271 0, 3.443724633133639 6.43684487617933 0, 3.441982126255169 6.436702999528588 0, 3.440078697608401 6.4385670468869645 0, 3.435853440367354 6.441392690971519 0, 3.4356648927168383 6.441445773552735 0, 3.4296424338548666 6.441583139796554 0, 3.427179994 6.442095174 0)	t	[3, 7, 2]	\N	Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	3	2	f	f
157	2026-03-03 09:16:01.543	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	Yes	\N	150	12000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (2.7098418861795324 6.430833386892971 0, 2.708308335947592 6.434169640892758 0, 2.7075534610814245 6.435813525126322 0, 2.707179873059058 6.43663164206431 0, 2.7067562426804272 6.437545387467075 0, 2.7067165814621497 6.43814666597224 0, 2.706665155656715 6.439075938660016 0, 2.706617300914612 6.439845461265318 0, 2.7064963073439543 6.4406647099465495 0, 2.7064341299436308 6.441124447943352 0, 2.7066907236299222 6.441692786636411 0, 2.7068774870217354 6.442597749960829 0, 2.7070551338990896 6.443455862282427 0, 2.7067598818667236 6.444566327249543 0, 2.7067394657202843 6.444789555554146 0, 2.706719049573845 6.445012783858749 0, 2.7066094495924458 6.446102841426895 0, 2.7064335939027417 6.447192898995041 0, 2.706446288924665 6.447770986702859 0, 2.7078758443312827 6.450567013258221 0, 2.7172136769831354 6.455887988916274 0, 2.7283240997177245 6.456792385165016 0, 2.736116938546715 6.451906224680187 0, 2.7425609074106205 6.446672115783485 0, 2.750352689812047 6.44392490256778 0, 2.784828728808918 6.450154945731654 0, 2.792091053442377 6.4556335172823935 0, 2.7996423332329528 6.456729520342023 0, 2.8083644389802203 6.454506074587492 0, 2.819063300009816 6.450758182521099 0, 2.8328956711597755 6.43926984414226 0, 2.857170338189121 6.42382130511119 0, 2.8762466430654285 6.414452712677658 0, 2.8783986250776366 6.412644449526134 0, 2.8867774464616787 6.407850822817434 0, 2.8999259699936317 6.40765145197166 0, 2.9218421276974027 6.408141714800692 0, 2.9332603300138302 6.407640062324447 0, 2.9431259032582915 6.40805378572918 0, 2.9567581000874554 6.408810780722831 0, 2.9656849528465443 6.4093011439179435 0, 2.978768762830043 6.407464540634265 0, 2.9856109123815884 6.406169209275703 0, 3.007097929859853 6.411859862480128 0, 3.0146606641147287 6.411199276772024 0, 3.0200073338357925 6.410698029690266 0, 3.0271601579156595 6.410019598699563 0, 3.032117766213787 6.409209399245455 0, 3.036565197598179 6.410060266291538 0, 3.049976920341294 6.414777168934506 0, 3.0560123175735328 6.415558197114393 0, 3.0619783605317537 6.415585956420259 0, 3.0652026359646527 6.411317981626269 0, 3.0666445294209836 6.409874723742448 0, 3.0759171923993733 6.4100751171334664 0, 3.0822202529548974 6.410432997532496 0, 3.0944448873989927 6.407140583535977 0, 3.099990727216948 6.407566221717488 0, 3.107705626956573 6.409574446817942 0, 3.1152938117107567 6.413910123973068 0, 3.127905263156947 6.411478157945652 0, 3.137472212243381 6.410141203340558 0, 3.1469711563810847 6.4116734709468375 0, 3.1522536607055827 6.412235398987619 0, 3.1547407806594663 6.412049971867958 0, 3.1570389450560867 6.410639185898901 0, 3.159003530417891 6.408989428219712 0, 3.1632840149539447 6.405216638225326 0, 3.1694125629994687 6.404744604869052 0, 3.1703049703056365 6.404977501808553 0, 3.1776226672490395 6.413680815649528 0, 3.1804134985221424 6.415326030594201 0, 3.181201092932497 6.4155456165808005 0, 3.1866472290188597 6.413016248878677 0, 3.192842882601923 6.407087357917106 0, 3.198162747571075 6.407091714727457 0, 3.202195909290964 6.412695756114516 0, 3.201008038899346 6.416623393888216 0, 3.1995200261578134 6.417719394716244 0, 3.1989847094658046 6.422570699803558 0, 3.1999512177159204 6.428639726333259 0, 3.1992871176654205 6.432178008974603 0, 3.201055524588611 6.434405254804403 0, 3.2054405097899803 6.433238791596821 0, 3.212093276125273 6.434305621910028 0, 3.218422513562871 6.435195708450358 0, 3.222964758257177 6.435542425265837 0, 3.2292242813069834 6.434941202765501 0, 3.236689038594278 6.437027196618345 0, 3.2399024724104777 6.434990856097727 0, 3.2412774060689173 6.433469324630323 0, 3.2434988742381847 6.428654708870518 0, 3.24537221459849 6.425313366473077 0, 3.2679335975688844 6.428072493418135 0, 3.2910155046445766 6.429778742031459 0, 3.2974770892164145 6.437075516495071 0, 3.3023185816296348 6.438558593387569 0, 3.3109126239101556 6.437222103280149 0, 3.31686107239031 6.431888914307862 0, 3.3187829339370296 6.431396265624954 0, 3.32062079189339 6.431899570966834 0, 3.3135205410310675 6.450098286267561 0, 3.3113308546409 6.454213454038637 0, 3.3082872698153096 6.458278688163816 0, 3.307736739005634 6.459066683593349 0, 3.3110925059611134 6.455619069332343 0, 3.3136665760423227 6.451240027706703 0, 3.318986782686636 6.438082548912789 0, 3.3212962480822625 6.431932563621672 0, 3.333762790405217 6.437094279049319 0, 3.3371559095434407 6.437301395107738 0, 3.339756950744274 6.437084841495874 0, 3.34507076732973 6.4354206104515725 0, 3.3571230547943287 6.439149776348984 0, 3.359173114029261 6.439063822478602 0, 3.366252543656742 6.431415386426039 0, 3.3681157876490886 6.43041644089584 0, 3.3807797298679247 6.435790405800674 0, 3.39461054614614 6.432865508786705 0, 3.3969184995401918 6.43547631629302 0, 3.397203152633324 6.43842655277696 0, 3.389712307222169 6.449208105545907 0, 3.386274275631351 6.449990730738904 0, 3.382788778497286 6.451301725482011 0, 3.380202991245568 6.453278504079506 0, 3.379047402885618 6.456951916515479 0, 3.3793335304544883 6.462160406228421 0, 3.382478287671148 6.4627345187174825 0)	t	[156, 57, 18, 92, 101, 10, 6, 1]	The bulk of the time duration is from port novo to gbaji due to checkpoints. Farisimeh is the port novo side of Nigeria 	Officer Samuel	Samuelolorunwamautin@yahoo.com	156	1	f	f
37	2026-02-10 10:09:51.269	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	\N	\N	30	2700	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.5010197 6.5393273 0, 3.469001122090702 6.494954741487431 0, 3.467065044572604 6.463647151729197 0, 3.4662791651411577 6.459470394839868 0, 3.4652317777494788 6.4546456409649755 0, 3.46443340969953 6.449433932047 0, 3.4593630870596055 6.4476939455620865 0, 3.456081288236424 6.450532963838811 0, 3.4531054383026816 6.449602521368319 0, 3.4530229308051226 6.445931285475844 0, 3.4530177232723966 6.43982062893625 0, 3.4495654834068366 6.4372769536334555 0, 3.446401390629092 6.437007940602944 0, 3.4437314780300596 6.436763794695786 0, 3.4419820549383355 6.436702570425009 0, 3.440239412233823 6.438725436792637 0, 3.4359241080804366 6.441564971412435 0, 3.435682742401845 6.441672118818423 0, 3.4296723803534577 6.441774659038057 0, 3.427179994 6.442095174 0)	t	[14, 12, 7, 2]	The morning frequency is extremely high on Mondays because people are going to the island but this morning frequency reduces during the week and becomes high again by weekend because people are going back home.\n\nThe ferry route costs 2700 in the mornings and 2200 in the evenings. The boat doesn't pick people up at intermediate stops, only drops them off	Mr Olabinjo Lateef	olabinjolafeef@gmail.com	14	2	f	f
107	2026-02-25 18:41:11.417	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	65	3500	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.600195878 6.56021613 0, 3.569401876233332 6.535112666286517 0, 3.5379806126384445 6.519839905146939 0, 3.474129030915237 6.489557489539898 0, 3.4674368315450392 6.4598769884752425 0, 3.467432513539869 6.454349244706966 0, 3.4674906950004107 6.450363852820928 0, 3.4616461078162213 6.449021965769328 0, 3.456063923160168 6.450173575148216 0, 3.454887437898669 6.450211526285684 0, 3.453843781618307 6.449850990479741 0, 3.453179636712623 6.449433527967596 0, 3.453198612281357 6.447820604625219 0, 3.453521196949832 6.443835735191111 0, 3.45306578330022 6.440420132819018 0, 3.4525339842229736 6.440075433703385 0, 3.4493676476471493 6.437691933633133 0, 3.4436816640243295 6.437007436003763 0, 3.4419823331789634 6.436702379801346 0, 3.439986734480111 6.438483241421429 0, 3.4358022402648345 6.441222097325601 0, 3.435604924065667 6.441284892252207 0, 3.4274563000862353 6.440934108053681 0, 3.423850870487048 6.439906441125591 0, 3.421846989424669 6.438886919966006 0, 3.418141158658537 6.437840304024391 0, 3.415964966706243 6.438160927237535 0, 3.41363882673951 6.438961000856666 0, 3.412453532488946 6.43942030237876 0, 3.410157024878477 6.441050081973286 0, 3.40823092172131 6.441716809989227 0, 3.406408531811068 6.441850155592416 0, 3.405223237560503 6.441613096742303 0, 3.403993494775542 6.440753758410644 0, 3.40311934026575 6.439983317147777 0, 3.402585957852997 6.439257324419307 0, 3.402378531359149 6.439212875884912 0, 3.40203775926211 6.439257324419307 0, 3.389713112398539 6.4492081354225945 0)	t	[42, 7, 6]	\N	Sikigha Charity	isikighacharity@gmail.com	42	6	f	f
29	2026-02-09 13:47:07.727	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	2	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.258691 6.427831 0, 3.255345985 6.424950503 0)	f	[70, 59]	\N	Mr Damilola	damexsy@gmail.com	70	59	f	t
4	2026-01-13 00:00:00	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash,Bank Transfer	Covered	\N	\N	25	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.427179994 6.442095174 0, 3.430349916181143 6.442022813155185 0, 3.435710521305812 6.442191379059877 0, 3.4371876354201163 6.441659011870856 0, 3.4399969986244896 6.440410320841825 0, 3.4432902916822505 6.438064502707718 0, 3.4452381678590798 6.437951952707851 0, 3.4487696164089496 6.4388927759818015 0, 3.451393410980398 6.440630363266215 0, 3.452119474852506 6.44098842059255 0, 3.452258864503755 6.441569210806088 0, 3.452514412197712 6.443567129140662 0, 3.452420613963269 6.44486041590274 0, 3.452192907138463 6.448636554080776 0, 3.452496516238204 6.450040746167081 0, 3.453179636712623 6.450439233110491 0, 3.453824806049574 6.450856695622636 0, 3.454887437898669 6.451008500172505 0, 3.455703387354224 6.451046451309973 0, 3.456348556691175 6.450837720053902 0, 3.458625624939237 6.450116648442015 0, 3.460200597144147 6.449490454673799 0, 3.46228790970487 6.449338650123928 0, 3.465565866469349 6.449277731113232 0, 3.468026031176199 6.449941585081747 0, 3.468182232109967 6.451074041851566 0, 3.467947930709315 6.452792252123016 0, 3.467635528841778 6.454119960060046 0, 3.466659273005727 6.457009677334758 0, 3.466464021838517 6.459079339707188 0, 3.466422591010072 6.462746831441437 0, 3.466440812907292 6.481922133147788 0, 3.466499213955513 6.496023679655265 0, 3.5010197 6.5393273 0)	f	[2, 14]	\N	Lanre	antholaredo@gmail.com	2	14	f	f
23	2026-03-13 12:58:01.914	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	75	3500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3591726742562287 6.439065516882735 0, 3.363690943422938 6.4331370060584305 0, 3.364031577560098 6.432712431209637 0, 3.3560023969929773 6.427307649732441 0, 3.34351702750196 6.421668691643724 0, 3.332047375595039 6.415300762093608 0, 3.322766033210854 6.411937238826582 0, 3.3108862458908845 6.412898148707953 0, 3.2965199914567336 6.412074511777661 0, 3.2878864250901643 6.4098095033605915 0, 3.2774091342538725 6.412928809536382 0, 3.2600161077751295 6.40894013382588 0, 3.239278268511356 6.415920295839442 0, 3.2364909245251 6.416474272856746 0, 3.2248955735389586 6.4068349868475565 0, 3.212431456861708 6.415282882787636 0, 3.2096083056566727 6.41715319472722 0, 3.2027386377234848 6.413506080085881 0, 3.1969247797368325 6.406385326689687 0, 3.1927892848335375 6.406370834829403 0, 3.182655829518694 6.414671233491397 0, 3.180783427910768 6.415404145990848 0, 3.1780839323155874 6.4137477917416135 0, 3.1702735633413397 6.404555715225349 0, 3.1677704051578246 6.404478480466949 0, 3.163464748949636 6.404708487126733 0, 3.160930706968486 6.40634836208082 0, 3.1573542891098327 6.410166267725845 0, 3.154639201909589 6.411569592687037 0, 3.149724427434961 6.4112970213573135 0, 3.139061306109273 6.409483013244284 0, 3.130660301548353 6.410190245955306 0, 3.1251120325574817 6.41162973089277 0, 3.119125407791607 6.413035681940478 0, 3.1150295004572115 6.413189184351381 0, 3.113012352764983 6.412222241016522 0, 3.1091695310535954 6.409258032144649 0, 3.1022408977017335 6.405799469157287 0, 3.093548911789185 6.4048874650817 0, 3.091661082930443 6.406112177388152 0, 3.0856100442273657 6.407959414947513 0, 3.07658157375468 6.4089056361960814 0, 3.0668579539077427 6.408327948861256 0, 3.0547241640876805 6.410027939953899 0, 3.051287639531651 6.413283872788767 0, 3.0475735827799895 6.412643244111905 0, 3.044190793766038 6.41016288155775 0, 3.037302317397497 6.407101902312656 0, 3.033068624681434 6.406689475261931 0, 3.0240169580231395 6.403735655766759 0, 3.0169128954505453 6.405088176897035 0, 3.0108800151251387 6.409440637381451 0, 3.0087447173133626 6.410380763096654 0, 2.9858130946558106 6.4045516795446815 0, 2.9654342532945606 6.407772986662284 0, 2.9581862139644954 6.407296624563649 0, 2.9537150567586252 6.40640501603815 0, 2.9445104830466278 6.40173157790376 0, 2.9392026841148393 6.401009077874495 0, 2.9352381602582085 6.402667749957708 0, 2.9268008462989314 6.4056243045465635 0, 2.9218927107811314 6.406759750106101 0, 2.9180680333889946 6.406417307994381 0, 2.911443517759757 6.405857833522376 0, 2.899349438886773 6.404797450243564 0, 2.8831690465842996 6.40604891645404 0, 2.8753722227112277 6.411608209262527 0, 2.8726652616008295 6.414190307628903 0, 2.871221344301631 6.415124932065034 0, 2.8607514390517395 6.419570726467086 0)	f	[10, 57]	\N	Fisayo 	fisayo@publictech.studio	10	57	f	f
92	2026-02-25 09:41:51.816	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	\N	\N	5	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.6152376980551537 6.5121898779015055 0, 3.616397550098327 6.513740573721314 0, 3.618240456707996 6.51395443049776 0, 3.620678072972826 6.513150676698902 0, 3.6246612410186074 6.509278152641569 0, 3.627275190194908 6.504684408302328 0, 3.6287200743357744 6.50069993542219 0)	f	[200, 86]	Although a person can wait on average for 25 minutes for the boat to be filled but if there are 5 passengers then the boat can move 	Mr Haruna deji 	Harunadeji05@gmail.com	200	86	f	f
164	2026-03-05 15:08:16.184	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	Yes	\N	35	500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.347764109790347 6.426358133440893 0, 3.3488889807153273 6.423671898279153 0, 3.3493211647678094 6.422210900422988 0, 3.3556066785051613 6.427430993645757 0, 3.3634513209103636 6.432960952557403 0, 3.359173518605778 6.439063191871019 0)	t	[84, 64, 85, 10]	\N	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	84	10	f	f
32	2026-04-08 08:58:23.379	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	100	9000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	\N	t	[18, 13, 140]	Destination is ponton 	Mr olayinka	olayinkamubo26@gmail.com	18	140	f	f
12	2026-02-09 08:44:22.291	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	Yes	4	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3700913 6.4346659 0, 3.370910736 6.429986033 0)	f	[27, 99]	Boats are also called Wooden boats. They still get water hyacinths but they push it away to make way	Mr Ibrahim Owolabi	owolabiibrahim580@gmail.com	27	99	f	f
9	2026-01-13 00:00:00	LagFerry/Government: Operated by the government	Cowry card	Catamaran,Covered	\N	\N	45	2200	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4862304 6.601832 0, 3.4752106563543474 6.587861802162575 0, 3.4502330993444277 6.549709647042801 0, 3.4258333213746655 6.51525094157288 0, 3.402869426193956 6.490042834988112 0, 3.3830376165132807 6.463432525332177 0, 3.382478301866796 6.462734506635153 0, 3.381403492985905 6.462675988078655 0, 3.3792338207578236 6.462280507457692 0, 3.3786713553347925 6.45687139915713 0, 3.379861675457275 6.453092100262134 0, 3.3825914299988242 6.451052821660096 0, 3.3861241115506617 6.449710980073286 0, 3.3897130787985748 6.449208079780339 0, 3.3785629830923933 6.448236399786917 0, 3.3749219 6.4477052 0)	t	[3, 1, 6, 5]	\N	Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	3	5	f	f
19	2026-02-09 11:11:38.152	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	10	200	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3591733715160426 6.439064183735342 0, 3.356829582371355 6.439594492712476 0, 3.355438129201781 6.439427348685829 0, 3.3540080948982025 6.439082041257653 0, 3.3515069341547616 6.43788989388192 0, 3.349280310206545 6.4369464015389255 0, 3.349168982656728 6.437257314412614 0, 3.349115969538495 6.438300463791504 0, 3.3491009592150194 6.439244036657316 0, 3.349265503813207 6.443664793371199 0, 3.3494544645639412 6.444569976704161 0, 3.3504115957878566 6.446510833747375 0, 3.3513312088760943 6.448748074620233 0, 3.3514861604728243 6.44971638807712 0, 3.3515763778302703 6.4503921270555615 0)	f	[10, 35]	About 30-seater boats	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	10	35	f	f
28	2026-02-09 13:46:10.555	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	2	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.258683952703204 6.427839632790165 0, 3.26227376609746 6.425672630901779 0)	f	[70, 125]	\N	Mr Damilola	damexsy@gmail.com	70	125	f	f
108	2026-02-25 20:54:41.149	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	40	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.310792342 6.437342371 0, 3.3194089632410453 6.432069477432194 0, 3.3209642887536006 6.431888045331661 0, 3.3229966073384674 6.432264567103331 0, 3.3286457640850244 6.435841510024574 0, 3.3346685278221173 6.437324709657744 0, 3.3379313820809386 6.43748244228334 0, 3.3474730261550576 6.435568447600829 0, 3.3483202624996977 6.435617970980985 0, 3.355521771428812 6.43866364959888 0, 3.358312667621732 6.439059834092319 0, 3.359173604139272 6.4390639714181646 0, 3.365812882420073 6.431552015158104 0, 3.3806475009272674 6.4356693835266725 0, 3.3919013494485455 6.432975306762131 0, 3.3963005811434357 6.433076970295701 0, 3.3977489450779217 6.438553624866415 0, 3.389713112398539 6.4492081354225945 0)	t	[92, 10, 6]	\N	Sikigha Charity	isikighacharity@gmail.com	92	6	f	f
13	2026-02-09 08:46:02.911	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	Yes	4	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3700913 6.4346659 0, 3.3733927 6.4311226 0)	f	[27, 91]	Boats are also called Wooden boats. They still get water hyacinths but they push it away to make way	Mr Ibrahim Owolabi	owolabiibrahim580@gmail.com	27	91	f	f
43	2026-02-11 09:25:59.655	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Wooden boats	Yes	\N	5	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.20189717 6.563707 0, 3.200954686933727 6.563754161317007 0, 3.2001329932358544 6.563954657910514 0, 3.199820653526473 6.5638400884380275 0, 3.1992824681807406 6.563482058668228 0, 3.199080648675988 6.563343620421037 0, 3.198869218718329 6.563267240682748 0, 3.1988355821339667 6.563190860931485 0, 3.198648178307792 6.56314312358144 0, 3.1983694751827443 6.562808962003331 0, 3.1981772661307843 6.562775545832906 0, 3.1979225891359704 6.56268484478781 0, 3.1977315005038633 6.562585440369432 0, 3.1975558702352487 6.562529606935243 0, 3.197246760962713 6.562383044141967 0, 3.197014929007622 6.562281845998356 0, 3.196484525595878 6.56216668946368 0, 3.1960770633722007 6.5620550224960965 0, 3.195462 6.561944 0)	f	[71, 144]	Destination is Ijon Odo	Adeyeye Omotolani	omotolaniadeyeye@gmail.com	71	144	f	f
36	2026-02-10 09:24:37.357	LagFerry/Government: Operated by the government	Cowry card	Covered	\N	\N	40	2200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.472861666725476 6.552351446907041 0, 3.4432387976488785 6.523250980436249 0, 3.403010921729284 6.487805305761261 0, 3.3882024169275686 6.468693684643348 0, 3.3825059373731294 6.465593168746079 0, 3.375944956456408 6.459907635493732 0, 3.3759327676650726 6.452492879800741 0, 3.3883839533469873 6.444304244072807 0, 3.3967311670392935 6.438292209535858 0, 3.396562509929246 6.437413284784931 0, 3.394305476693841 6.43280505454388 0, 3.391842635473581 6.433418707041351 0, 3.380843541115392 6.436742379532573 0, 3.377129518807548 6.435131128881921 0, 3.368167138550125 6.432226300375852 0, 3.3641792601216762 6.433595286054489 0, 3.359173996142955 6.4390625163644755 0)	f	[15, 10]	This route only works during the water hyacinth season 	ISHOLA TAIWO OLANREWAJU 	isholataiwoolanrewajutiems@gmail.com	15	10	f	f
30	2026-02-09 13:53:15.585	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	No	Yes	25	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.258691 6.427831 0, 3.256180561773192 6.426316216996483 0, 3.244916217511559 6.4254521667465525 0, 3.2446885046995533 6.424929976349759 0, 3.244688504698047 6.421048503700959 0, 3.2450101061180305 6.4186744457267935 0, 3.2476171365445623 6.415649600606585 0, 3.250474116753253 6.41258796883281 0, 3.252033208416293 6.41143004192692 0, 3.2535695441037262 6.410994586931963 0, 3.254787460435665 6.411162252361791 0, 3.255507704262243 6.411405073247323 0, 3.255760155 6.411298075 0)	t	[70, 120, 62]	On Weekends, there’s beach activity which makes the frequency faster in the afternoons.	Mr Damilola	damexsy@gmail.com	70	62	f	f
156	2026-03-03 09:15:26.92	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	Yes	\N	150	12000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (2.6234022025985553 6.466001455685301 0, 2.6263465944822286 6.464218875874991 0, 2.628491041230234 6.463059293757311 0, 2.6447500483373574 6.457743249197392 0, 2.6642851951660305 6.446079239727396 0, 2.6722846212281297 6.44373277904937 0, 2.6908417301740712 6.446283016088003 0, 2.7074587881646437 6.453882562516327 0, 2.716034684737494 6.458103472282417 0, 2.7283578809825144 6.4592412206635 0, 2.7393801378924962 6.452705096021354 0, 2.7443167338416288 6.449512839059565 0, 2.751334377543344 6.447476486252853 0, 2.7812704812797335 6.451796401198223 0, 2.7846795599949985 6.453007033807104 0, 2.790553861730956 6.4580452312373104 0, 2.7996851404267886 6.460235613878439 0, 2.8202829011129324 6.452534991814304 0, 2.8518438313936656 6.429105356812087 0, 2.860755439101183 6.419559539927235 0, 2.870297827612603 6.4157397710867485 0, 2.874444425608715 6.413811834692396 0, 2.8779934979075392 6.410709463834635 0, 2.8836168963792943 6.406916104022088 0, 2.8864116891401466 6.406589577321313 0, 2.8993000344342477 6.405434624462501 0, 2.9216486366928223 6.407128563554494 0, 2.927466605524174 6.40592444381091 0, 2.938927279730585 6.401707440793121 0, 2.944588979865898 6.402386268505822 0, 2.953395692783033 6.407014838368795 0, 2.9570101247395257 6.407637553745715 0, 2.9657222091477564 6.408167193652339 0, 2.98572001801719 6.4050602878331375 0, 3.0079984112140608 6.410724022523183 0, 3.0098789248071114 6.410671620497084 0, 3.012381778592669 6.4090764636667785 0, 3.01723537222756 6.405561874440302 0, 3.0240365699480662 6.404369815733446 0, 3.0279391145382135 6.405517837687043 0, 3.033336600588626 6.407232606363692 0, 3.036952503234346 6.407660179945182 0, 3.0432344587902733 6.410298341365536 0, 3.047367978577185 6.412990372564757 0, 3.0515441417827844 6.4138824792410105 0, 3.055017170930711 6.410610468055509 0, 3.0671719170974825 6.4087871606377576 0, 3.0800078682151195 6.40906401196311 0, 3.088346244955261 6.407591335535415 0, 3.09218813796069 6.406311957805364 0, 3.0938853545545513 6.405432870707099 0, 3.1017879701566073 6.406215726662353 0, 3.108432408969435 6.409201513530945 0, 3.1085808673872464 6.417536293357671 0, 3.109698145025021 6.422999867185503 0, 3.111246279583753 6.426143740573803 0, 3.1132329514437345 6.427110016360345 0, 3.1174822798533626 6.4260803922622785 0, 3.122518095434998 6.425537827284444 0, 3.130906587102885 6.4267370724532356 0, 3.134507737202327 6.426739495916827 0, 3.1375590477338946 6.425563283576583 0, 3.140223310760444 6.423993401023148 0, 3.142259503895948 6.421972571105724 0, 3.1453432266097776 6.420277757257393 0, 3.147588500503531 6.419726948123028 0, 3.1501045601061435 6.420402530726491 0, 3.1538297697275084 6.42364694114795 0, 3.1577791243086892 6.425001547466238 0, 3.160675544873399 6.427165834729578 0, 3.1621982563322035 6.42922937549146 0, 3.1634660767387004 6.433110527813 0, 3.1654163366661976 6.437184854773932 0, 3.1669491267279 6.43923671072104 0, 3.1686699627023813 6.440557458696489 0, 3.171795876143392 6.4409752415151615 0, 3.174024888513543 6.4402378417328805 0, 3.1808835586816144 6.436653895046348 0, 3.1839246667385055 6.434831493491728 0, 3.185923344442969 6.43394094556988 0, 3.1875506156275506 6.4336494736175105 0, 3.192485535342886 6.435240718824284 0, 3.195436171926019 6.436649317958782 0, 3.2000003553137617 6.435177497141041 0, 3.205593443711024 6.433674310079965 0, 3.220151156433076 6.435489799941408 0, 3.2292242813069834 6.434941202765501 0, 3.236689038594278 6.437027196618345 0, 3.2399024724104777 6.434990856097727 0, 3.2412774060689173 6.433469324630323 0, 3.2428710791723745 6.429028910835299 0, 3.245723597567263 6.426219299628642 0, 3.2883887332324093 6.429857840469339 0, 3.2910155046445766 6.429778742031459 0, 3.2987366206136812 6.437213941308485 0, 3.3023185816296348 6.438558593387569 0, 3.3109126239101556 6.437222103280149 0, 3.3179809834818457 6.432511621624812 0, 3.320118011193358 6.432128995522717 0, 3.3208688587651523 6.432339439915793 0, 3.31201199729648 6.453170128614076 0, 3.3082872698153096 6.458278688163816 0, 3.3080592627921703 6.458632868521036 0, 3.307736739005634 6.459066517019849 0, 3.310514228007321 6.455844826695653 0, 3.3129464758149254 6.4520826197576895 0, 3.318986782686636 6.438082548912789 0, 3.321446957826396 6.432556567929581 0, 3.3224464039760733 6.4319199303144075 0, 3.333762790405217 6.437094279049319 0, 3.337507565612583 6.437625873976998 0, 3.347029993996955 6.435570370507776 0, 3.3483852459771413 6.4358184489544925 0, 3.3571230547943287 6.439149776348984 0, 3.359173114029204 6.439064488801108 0, 3.366252543656742 6.431415386426039 0, 3.3686181534615685 6.430840765119825 0, 3.380302482346764 6.436239685490705 0, 3.3819213927863245 6.4363966324711726 0, 3.3943593632403406 6.433414631551273 0, 3.396215187403641 6.43537647623188 0, 3.396824093156141 6.43830859877805 0, 3.3897124748618523 6.44920843870014 0, 3.386224149479901 6.44984536435728 0, 3.382712959524838 6.451209325051721 0, 3.3800764976100197 6.453182226109774 0, 3.3788788498852966 6.456928298044204 0, 3.379289545073675 6.462215965315565 0, 3.3814261022652516 6.46263309017619 0, 3.3824782876710344 6.462734352145162 0)	t	[4, 57, 18, 92, 101, 10, 6, 1]	The bulk of the time duration is from port novo to gbaji due to checkpoints 	Officer Samuel	Samuelolorunwamautin@yahoo.com	4	1	f	f
34	2026-02-10 09:15:04.963	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Cowry card	Speed boats	No	\N	30	2500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.4728735 6.5523891 0, 3.4610299356086838 6.529079908099284 0, 3.465871070608161 6.46521670519526 0, 3.465643966936233 6.462789111884183 0, 3.465565866469349 6.45911838994063 0, 3.465643966936233 6.457243978735411 0, 3.46595636880377 6.455369567530192 0, 3.466385921371633 6.45380755819251 0, 3.467205976273916 6.45134739348566 0, 3.466815473939495 6.450605439050261 0, 3.465604916702791 6.450175886482398 0, 3.464042907365109 6.449590132980767 0, 3.462591518804611 6.449642259223669 0, 3.460181621575412 6.44979406377354 0, 3.457790699914948 6.450666939935297 0, 3.456158801003837 6.451179280291111 0, 3.455134120292209 6.451198255859845 0, 3.454375097542855 6.451179280291111 0, 3.453445294674897 6.450970549035039 0, 3.45223085827593 6.450116648442015 0, 3.452098029294794 6.448921187611783 0, 3.451965200313657 6.448124213724961 0, 3.45207905372606 6.446738997207391 0, 3.452154956000995 6.445239927277417 0, 3.45232855932938 6.443207039208269 0, 3.452282096112297 6.442498475147751 0, 3.451910390375632 6.441197505069424 0, 3.4515448463044276 6.440543330834378 0, 3.4488281618000247 6.4388087451329525 0, 3.4452292417895647 6.437874451455791 0, 3.443264661528905 6.437977948470125 0, 3.4399056894551125 6.44027662977546 0, 3.437120765738393 6.441539322400302 0, 3.4357087691201538 6.442092949832996 0, 3.4303510832949207 6.441964180897786 0, 3.427176 6.442096 0)	f	[15, 2]	The reason we have 6:30-7:00 on weekend is because there's usually little to no activity and even if there is, it's a very small window and it only moves in one direction.\n	ISHOLA TAIWO OLANREWAJU 	isholataiwoolanrewajutiems@gmail.com	15	2	f	f
48	2026-02-11 13:28:20.508	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	No	Yes	40	1000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.2055781 6.453045 0, 3.206507009062568 6.447753733168739 0, 3.206549468624587 6.44759333037889 0, 3.206606081373945 6.4474895403384 0, 3.206757048705567 6.447263089340966 0, 3.207063701097925 6.446852646908118 0, 3.207120313847283 6.446753574596741 0, 3.207162773409302 6.446512970411968 0, 3.207077854285265 6.445913818814591 0, 3.206922169224529 6.445319384946329 0, 3.206880303143875 6.444715659936991 0, 3.206716143952759 6.444024095685053 0, 3.206611361490344 6.44379357426774 0, 3.206992071103785 6.443496690624233 0, 3.207093360817452 6.443206792478219 0, 3.207110824561188 6.442976271060906 0, 3.207093360817452 6.442218344582773 0, 3.207087422275739 6.441972286081016 0, 3.207058059727502 6.441838523361273 0, 3.206675938787262 6.441918250835998 0, 3.206243656827114 6.442209225532754 0, 3.206215925531559 6.442215138823721 0, 3.205791799834811 6.442375001586341 0, 3.20531873655767 6.442355426554183 0, 3.205077311161059 6.442244501371957 0, 3.20493034267917 6.442150338416655 0, 3.204285751505772 6.441704438429321 0, 3.203959990375129 6.441401780924966 0, 3.203785557996665 6.441354418491078 0, 3.203564692343531 6.441242737999472 0, 3.203400667163599 6.441170960117492 0, 3.203338883817041 6.440800074521579 0, 3.203299037399683 6.440642681173014 0, 3.203243252415381 6.440407587310599 0, 3.203245244736249 6.440385671781051 0, 3.203257198661456 6.440301994304598 0, 3.203249229377985 6.440246209320297 0, 3.203251221698853 6.440220309149014 0, 3.203267160265796 6.440041000270901 0, 3.203241930853736 6.440001551200425 0, 3.202966336252044 6.439760168342391 0, 3.202766767747371 6.439528288746485 0, 3.202753876768035 6.439502191847852 0, 3.202203687836461 6.439092172085316 0, 3.202045470151907 6.438640208900688 0, 3.202045470151907 6.438633081454093 0, 3.202045945315013 6.438625478844391 0, 3.202047845967439 6.438616925908477 0, 3.202071022216864 6.438311661017526 0, 3.202078203030754 6.438183603169832 0, 3.202035118147418 6.437937061892962 0, 3.202027937333528 6.437876024974902 0, 3.20200878849649 6.437765919161931 0, 3.20082636677412 6.437441994377468 0, 3.199756112006094 6.43715923571036 0, 3.199639837414012 6.436902903086906 0, 3.199552631469951 6.436702065155129 0, 3.1995313545348125 6.436384278990706 0, 3.199567656320274 6.435921149579246 0, 3.199646934451239 6.435623156949082 0, 3.2001354082008246 6.433292234701217 0, 3.199922214137146 6.432759232131751 0, 3.1996089844113307 6.4322429170687325 0, 3.1996085041686833 6.430450701985262 0, 3.1997482387104133 6.429165693153001 0, 3.1998551860050477 6.427028671131331 0, 3.1994435354969037 6.424659668944023 0, 3.1991685369020644 6.421904736017284 0, 3.198991802989313 6.418771317346787 0, 3.199705611290856 6.417086779951141 0, 3.2002584058357857 6.416089523093111 0, 3.20121531573126 6.415119224661087 0, 3.2018701422779334 6.413333736751193 0, 3.1999147121518763 6.410165812732754 0, 3.1972785701516298 6.4081782047899924 0, 3.1941694526290196 6.407547361436321 0, 3.1915368136561915 6.408677677505447 0, 3.1829462734779224 6.415385859614633 0, 3.1813587271909425 6.416144272746559 0, 3.176731213515937 6.4147366868836935 0, 3.175259524468374 6.412147555168023 0, 3.1701586529056414 6.405512854020799 0, 3.164768668 6.403919063 0)	f	[9, 19]	\N	Mr Pascal	N/A	9	19	f	f
71	2026-02-20 11:07:46.599	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	No	Yes	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	LineString Z (3.2616159304640178 6.407584812481417 0, 3.2605470575297772 6.40744777275269 0, 3.2556342103025315 6.411504310045416 0, 3.255300614439932 6.411317163616957 0, 3.2542675023519223 6.411349652567893 0, 3.2524660948806456 6.4119734400257755 0, 3.243441896844587 6.409074449829603 0, 3.2476566930685635 6.415678302516511 0, 3.246097756810798 6.416809692198299 0, 3.245004902531207 6.418674789028032 0, 3.2446960524086137 6.420823183239591 0, 3.2447673255132656 6.425214378369972 0, 3.2503844843803904 6.426174645711939 0, 3.2522147173987435 6.426214183394208 0, 3.25535825779761 6.425053675366328 0, 3.2575065080177126 6.4246903799026995 0, 3.26224407925514 6.425798003775398 0, 3.2587013221436507 6.427857404741758 0)	t	[60, 114, 62, 44, 119, 93, 120, 59, 30, 125, 70]	The route gets the most traffic on weekends because of the beach houses on the Ibese shores, the price also increases on weekends by 500naira due to increase in demand	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	60	70	f	f
40	2026-02-10 12:27:52.973	LagFerry/Government: Operated by the government	Cowry card	Covered	Yes	\N	30	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.5890471 6.5632172 0, 3.5672873342029794 6.537141320555509 0, 3.5349949452306118 6.520392307813857 0, 3.473219400397198 6.491688510058024 0, 3.467837774009678 6.463292185930974 0, 3.4662568017525204 6.456723430979685 0, 3.46443340969953 6.449433932047 0, 3.456081288236424 6.450532963838811 0, 3.4531054383026816 6.449602521368319 0, 3.4530229308051226 6.445931285475844 0, 3.4526005934890387 6.44002484997792 0, 3.449404646300565 6.437612058325149 0, 3.4437232518822896 6.4369732684380025 0, 3.4419823902133824 6.436702737006566 0, 3.4401946909370205 6.438656367751662 0, 3.4358887664506965 6.44149739560917 0, 3.4356654057995546 6.441585138063656 0, 3.4296605416577735 6.4417107081843845 0, 3.427179994 6.442095174 0)	t	[69, 7, 2]	It's a fairly new route so it's not yet popular. Also the boats only drop off when it's an outbound route and thy only pickup when it's an inbound route	Mr Michael Diyepiriwei	diyemichael@gmail.com	69	2	f	f
47	2026-02-11 13:25:15.377	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana	Yes	\N	45	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.2055781 6.453045 0, 3.213537175940317 6.443705417783854 0, 3.220390916321497 6.436563701627779 0, 3.229715351005915 6.43247337383163 0, 3.2353591104455037 6.4295562149907415 0, 3.2398290907464204 6.427887642619536 0, 3.242765511589867 6.426219070248331 0, 3.243562714581501 6.422761350553254 0, 3.2435062718470267 6.420675321871601 0, 3.24319428707592 6.419052933711599 0, 3.243296800242576 6.418006630991536 0, 3.2432279642128887 6.417197976115749 0, 3.242400989331251 6.416903162902312 0, 3.236195917891799 6.416023554348714 0, 3.2296750489391384 6.4099872073989745 0, 3.226439799544212 6.407790168124701 0, 3.22075870239245 6.406926003137938 0, 3.212589230878601 6.408723075349343 0, 3.2055711 6.40667 0)	f	[9, 77]	\N	Mr Pascal	N/A	9	77	f	f
73	2026-03-04 00:35:17.235	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	Yes	\N	35	2500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4419826471853696 6.436702621424786 0, 3.443633869921191 6.437183644250093 0, 3.449172682809203 6.438169638974981 0, 3.452068097740721 6.440341394711923 0, 3.4522185 6.4427855 0, 3.451680566782649 6.448029335881293 0, 3.45198417588239 6.450325379698088 0, 3.453691977068437 6.451501864959586 0, 3.456310961143582 6.451425493952544 0, 3.458185372348801 6.450800690217472 0, 3.459981683087135 6.450097786015514 0, 3.461621792891702 6.449941585081747 0, 3.462910450595289 6.450058735782072 0, 3.463925756664783 6.450488288349935 0, 3.465370615302139 6.45115214231845 0, 3.465917318570328 6.452050297687618 0, 3.465526816235907 6.453182754457437 0, 3.465097263668045 6.454627613094793 0, 3.464667711100182 6.461188052313059 0, 3.455297283249439 6.546364120268855 0, 3.4754239121114496 6.581416478339578 0, 3.480935439482427 6.591761191251312 0, 3.4862304 6.601832 0)	f	[7, 3]	\N	Israel Ekundayo	israelekundayo@gmail.com	7	3	f	f
53	2026-02-13 09:42:16.307	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	Yes	\N	2	100	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.1439026468631823 6.449378262193392 0, 3.145117585903165 6.449265497044593 0)	f	[51, 141]	\N	Mr Olowoseelu Festus	Remiolusoji7@gmail.com	51	141	f	f
45	2026-02-11 13:11:40.484	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	Yes	\N	37	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.2055781 6.453045 0, 3.199973014889986 6.44924766057521 0, 3.198820781828631 6.447892503582012 0, 3.1980634475332828 6.448318189940002 0, 3.1973605843238517 6.448439002217537 0, 3.1962278873935293 6.447878552738921 0, 3.1958022825542045 6.448222289093553 0, 3.1951582827146994 6.449184158390468 0, 3.190336296168261 6.448945328381154 0, 3.190108700740698 6.44717478507785 0, 3.1894842344428587 6.446701250902201 0, 3.187172055340014 6.447117308478079 0, 3.1851638105138953 6.446716905894055 0, 3.183852294551066 6.446088650056611 0, 3.1830716415167197 6.44519076395503 0, 3.182925981877554 6.444336695895039 0, 3.1834482185225856 6.443421282404239 0, 3.184842050434117 6.442325322166363 0, 3.1861565081729357 6.441369153736541 0, 3.1871462640571235 6.440710095755794 0, 3.1875592529854098 6.440570304172597 0, 3.1841892312428204 6.438215365861761 0, 3.183755188123402 6.43822412959572 0, 3.183026503788277 6.438670437092647 0, 3.1818744905242347 6.438836305288792 0, 3.178630233545138 6.438831478652006 0, 3.175295272479863 6.440570977419682 0, 3.1729130744724126 6.44177124325536 0, 3.168680870735124 6.441646712033163 0, 3.166052483140002 6.4401788901745 0, 3.164220303646933 6.437949834786924 0, 3.163159957467908 6.434237890209866 0, 3.1616330957430177 6.429883301776516 0, 3.159569164854714 6.4275837988729005 0, 3.155662917584274 6.425308209577167 0, 3.1543194472877625 6.424888976278016 0, 3.153021847003207 6.424452718031615 0, 3.1529759503605135 6.424470195400829 0)	f	[9, 81]	The peak periods happen when they have parties	Mr Pascal	N/A	9	81	f	f
91	2026-02-25 09:37:40.224	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	\N	\N	15	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.6152375956363008 6.512190129667568 0, 3.6276820780229726 6.533090026688282 0, 3.6414235770015217 6.558735551880432 0, 3.6411438765730493 6.561326018985101 0, 3.6406805514803344 6.5624713348154025 0, 3.640324374369044 6.563172203228879 0, 3.640220691492774 6.563707003418976 0, 3.6402554044713717 6.564078525106597 0, 3.64004019065142 6.564709928394159 0, 3.639972362413536 6.565193131423041 0, 3.6399366370460475 6.565679793195663 0, 3.6394155664758117 6.566975144177748 0, 3.638903478516565 6.567571857361696 0, 3.6381986367689367 6.568570668053103 0, 3.6371527780015467 6.569557843002497 0, 3.636668447954762 6.570277887448642 0, 3.636112641654128 6.5713246268162 0)	f	[200, 58]	Workers use this route	Mr Haruna deji 	Harunadeji05@gmail.com	200	58	f	f
63	2026-02-18 15:27:07.341	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	9	400	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.359172912897035 6.4390640082534985 0, 3.364272597850107 6.432563835800667 0, 3.359255410786096 6.427659970091112 0)	f	[10, 85]	Market days are the greatest time to take this route. The market days are tuesdays, fridays, and saturdays, and wait times are almost nonexistent these days. Ideally, boat operators should not take trips after 6:00pm, but many do and close by 8: 00pm	Fisayo 	fisayo@publictech.studio	10	85	f	t
65	2026-02-18 21:02:57.741	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Bank Transfer, Cash	Banana, Wooden boats	No	Yes	35	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	LineString Z (3.204245481 6.453176022 0, 3.204691272048581 6.451306611466339 0, 3.206286535856859 6.447691481869566 0, 3.207021241535907 6.446734703680288 0, 3.207058983368812 6.446451639933496 0, 3.207073136556152 6.446220471206949 0, 3.20701180607768 6.446017608855081 0, 3.206874991933397 6.445489223194404 0, 3.206851403287831 6.445215594905838 0, 3.206804225996699 6.444706080161613 0, 3.206754564188978 6.444432747288471 0, 3.206611361490344 6.444041559428788 0, 3.206527535520412 6.443884385735166 0, 3.206503086279182 6.443779603272752 0, 3.206911246986321 6.443469776041071 0, 3.207035222189985 6.443091325419357 0, 3.207031959684626 6.442796068684314 0, 3.207031959684626 6.442169667655271 0, 3.207009122147109 6.442053848715006 0, 3.206969564269626 6.441954138394951 0, 3.206950397050636 6.441885829688987 0, 3.206819560367967 6.441900522322349 0, 3.206682097859101 6.44193717899138 0, 3.206556854239912 6.442025765941538 0, 3.206275819777342 6.442205994564274 0, 3.206031441983802 6.44230374568169 0, 3.205793173635101 6.442395387354266 0, 3.205686258350428 6.442386223187009 0, 3.205310527492861 6.442374004297332 0, 3.205050876087226 6.442248760678145 0, 3.204772896347075 6.442053258443313 0, 3.204284140759996 6.441714184254777 0, 3.203948121293879 6.441414821457691 0, 3.203789150136757 6.441369527365509 0, 3.203600712149039 6.441268060756738 0, 3.203392676480475 6.441178615486484 0, 3.203386699517871 6.441130799785653 0, 3.203358807025721 6.440997314287503 0, 3.203332906854437 6.440841913259805 0, 3.203299037399683 6.440680535269504 0, 3.203251221698853 6.440503218712259 0, 3.203231298490174 6.440395633385391 0, 3.203245244736249 6.440290040379391 0, 3.203238129548885 6.440241033406033 0, 3.203245732158587 6.440090881864421 0, 3.203253334768289 6.440049067511061 0, 3.203237227199949 6.440017658768764 0, 3.203113913993497 6.439907346520113 0, 3.203059773057337 6.439859522026505 0, 3.202975839514171 6.439782976171497 0, 3.202875950657815 6.439673585476046 0, 3.202806617388411 6.43958688975491 0, 3.202761060677791 6.439535973431276 0, 3.202744981838749 6.439503815753192 0, 3.202661907837032 6.439444860010037 0, 3.202503799253118 6.439329628330236 0, 3.202198301311318 6.439096485164126 0, 3.202039905356677 6.438649159270327 0, 3.202036314949733 6.438634797642549 0, 3.202044064682965 6.438582941520941 0, 3.202058903121032 6.438353316713476 0, 3.202069670598982 6.438179991338727 0, 3.202024113888362 6.437928089527067 0, 3.202000121152798 6.437775849379801 0, 3.201913346068144 6.437750730276349 0, 3.200908287509451 6.437481633442951 0, 3.199729685962439 6.437172448732188 0, 3.199509817228341 6.436724445702199 0, 3.199493808525991 6.436292210738742 0, 3.199541834633042 6.435795940965884 0, 3.199637886847143 6.435235636383625 0, 3.199862008680047 6.434339149052009 0, 3.1997841869184964 6.433438748806801 0, 3.199359806428408 6.43273181328109 0, 3.199198168707534 6.431818591734833 0, 3.199255843590292 6.430644201964959 0, 3.1994380185557665 6.426958699751105 0, 3.199341777141711 6.425125650963817 0, 3.1989498692047227 6.421862519723986 0, 3.1993084065809607 6.419539060415695 0, 3.198753850037465 6.4185382067447 0, 3.1990057328668655 6.417367093332628 0, 3.199419475461721 6.416346762494447 0, 3.2074984715131776 6.415971707178945 0, 3.210824404637061 6.415927806687773 0, 3.212965728872917 6.414245767461447 0, 3.2237268041425375 6.407223917048471 0, 3.2365837449062225 6.417414091167817 0, 3.2372597763751965 6.417350288914502 0, 3.2381149502855386 6.417642526504029 0, 3.2236778972348654 6.406081707185514 0, 3.216529244086983 6.407635772661759 0, 3.2152718637634554 6.408039987408987 0, 3.211038542705512 6.4083549122800285 0, 3.2055711 6.40667 0)	t	[107, 89, 73, 74, 122, 135, 100, 77]	The trip frequency increases on saturday evenings because of the beach houses along the route, and also there other minor stops on the route. The cumulative time from Ojo waterside to Ilashe is usually between 40mins-50mins	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	107	77	f	f
67	2026-02-18 23:19:26.76	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	Yes	\N	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	LineString Z (3.23811341801126 6.417628639562252 0, 3.2272602090868565 6.409757517783558 0, 3.2254231155984794 6.4085397038415515 0, 3.2232686200206953 6.4081659868844305 0, 3.2207713459128495 6.409586273475355 0, 3.2154762968180055 6.413005876008016 0, 3.212122823311799 6.416532338938524 0, 3.2094630115870144 6.417091732596178 0, 3.204770157372055 6.416312939988156 0, 3.201827439011633 6.4166571718915435 0, 3.2003417588756733 6.417426555989133 0, 3.1991616114517223 6.418975395484804 0, 3.1991658082454473 6.419394438591079 0, 3.199313162298789 6.419549122371283 0, 3.19940813382868 6.420974206348441 0, 3.1994976382440266 6.422546056697114 0, 3.1996237557023495 6.42477571842149 0, 3.2000000798854784 6.427003026230518 0, 3.1997046139062406 6.431425628865944 0, 3.1997381846599064 6.432159589725955 0, 3.200062631566629 6.432735366258572 0, 3.200267303534137 6.433160709837133 0, 3.200053897429205 6.434231285584525 0, 3.19962926699655 6.435940995097866 0, 3.199563201887413 6.436461588157869 0, 3.19957112970051 6.436696779946398 0, 3.199655693040205 6.436900260482541 0, 3.199771967632287 6.437151307897263 0, 3.200752373851886 6.437410283125082 0, 3.20200878849649 6.437758738348042 0, 3.202018362915009 6.437769509568876 0, 3.202082990240014 6.438193177588351 0, 3.202050221782971 6.438619776887115 0, 3.202049271456758 6.438627379496817 0, 3.202049271456758 6.438631655964774 0, 3.202050221782971 6.438640208900688 0, 3.202118645270287 6.43883740158983 0, 3.202205600118752 6.439091138688628 0, 3.202754779116971 6.439497680103172 0, 3.202767412002075 6.439521141175508 0, 3.202972245210545 6.439760263643545 0, 3.203241145193472 6.439994874366905 0, 3.203267160265796 6.440031038666562 0, 3.203277121870136 6.440044984912637 0, 3.203259190982324 6.440242224678562 0, 3.20326317562406 6.440286055737656 0, 3.203249229377985 6.440407587310599 0, 3.203350837742249 6.440823982371993 0, 3.203405503344249 6.44116843429947 0, 3.203641160332373 6.441274710980389 0, 3.203788335041375 6.441349388418964 0, 3.203967593928279 6.441399374070119 0, 3.204307767709364 6.441716179410287 0, 3.204816718545461 6.442062004978404 0, 3.205080981479588 6.442238180267823 0, 3.205328931886917 6.442349105450049 0, 3.205795470153339 6.442365417976847 0, 3.206229383366165 6.442202292708867 0, 3.206262008419761 6.442189242687428 0, 3.206646984052194 6.441924979753302 0, 3.206686134116508 6.441905404721144 0, 3.207284516819753 6.441786453757598 0, 3.207913350852247 6.441708545116405 0, 3.20858670410828 6.441502643707535 0, 3.20909311027604 6.441591682154614 0, 3.209593951540858 6.441352391328089 0, 3.209908368557105 6.441338479070733 0, 3.210222785573352 6.441191009142759 0, 3.210373037952797 6.441115882953037 0, 3.210612328779321 6.441129795210393 0, 3.210648500648447 6.441316219458963 0, 3.21067910761463 6.44146925428988 0, 3.210698584774929 6.441594464606085 0, 3.210851619605845 6.441647331184038 0, 3.211082563077956 6.441602811960498 0, 3.211268987326527 6.441694632859049 0, 3.211516625507465 6.441886622010562 0, 3.21157505698836 6.44192835878263 0, 3.211878344198722 6.441945053491457 0, 3.212039726384052 6.441936706137044 0, 3.212373620560597 6.441800366014954 0, 3.21263238854742 6.441552727834017 0, 3.212715862091557 6.441483166547236 0, 3.212697757950497 6.442439488371421 0, 3.205776272723006 6.451213609763073 0, 3.204245483565353 6.453176019638212 0)	t	[73, 89, 107]	Ikare village is very small, and the population reflects that, most of the boat actvities take place in the morning, when they go to the market at ojo	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	73	107	f	f
68	2026-02-18 23:21:08.232	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	Yes	\N	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	LineString Z (3.236747347 6.417336462 0, 3.230747874272814 6.412269804000883 0, 3.225238583047931 6.40835632435245 0, 3.223126060666493 6.408135629318128 0, 3.220710249046361 6.409566035152125 0, 3.215032802303151 6.413594518274495 0, 3.211966283168974 6.416402673340301 0, 3.2089233226028524 6.417041137533617 0, 3.2049941792152783 6.416292701932701 0, 3.2016135999796616 6.416626814828135 0, 3.1998529839453553 6.417568222034982 0, 3.1991616114517223 6.418975395484804 0, 3.1991658082454473 6.419394438591079 0, 3.199313162298789 6.419549122371283 0, 3.1993674025848375 6.421075395681876 0, 3.1994467241888467 6.422950812640763 0, 3.1996543041362475 6.42495785784266 0, 3.199979714262889 6.42706373911336 0, 3.199684248283623 6.431567291018999 0, 3.1997381846599064 6.432159589725955 0, 3.2003070190311345 6.432947858922435 0, 3.200236755101518 6.433828543093221 0, 3.1999317036962562 6.435071134597871 0, 3.199649632619111 6.436072537363941 0, 3.199563201887413 6.436461588157869 0, 3.19957112970051 6.436696779946398 0, 3.199655693040205 6.436900260482541 0, 3.199771967632287 6.437151307897263 0, 3.200752373851886 6.437410283125082 0, 3.20200878849649 6.437758738348042 0, 3.202018362915009 6.437769509568876 0, 3.202082990240014 6.438193177588351 0, 3.202050221782971 6.438619776887115 0, 3.202049271456758 6.438627379496817 0, 3.202049271456758 6.438631655964774 0, 3.202050221782971 6.438640208900688 0, 3.202118645270287 6.43883740158983 0, 3.202205600118752 6.439091138688628 0, 3.202754779116971 6.439497680103172 0, 3.202767412002075 6.439521141175508 0, 3.202972245210545 6.439760263643545 0, 3.203241145193472 6.439994874366905 0, 3.203267160265796 6.440031038666562 0, 3.203277121870136 6.440044984912637 0, 3.203259190982324 6.440242224678562 0, 3.20326317562406 6.440286055737656 0, 3.203249229377985 6.440407587310599 0, 3.203350837742249 6.440823982371993 0, 3.203405503344249 6.44116843429947 0, 3.203641160332373 6.441274710980389 0, 3.203788335041375 6.441349388418964 0, 3.203967593928279 6.441399374070119 0, 3.204307767709364 6.441716179410287 0, 3.204816718545461 6.442062004978404 0, 3.205080981479588 6.442238180267823 0, 3.205328931886917 6.442349105450049 0, 3.205795470153339 6.442365417976847 0, 3.206229383366165 6.442202292708867 0, 3.206262008419761 6.442189242687428 0, 3.206646984052194 6.441924979753302 0, 3.206686134116508 6.441905404721144 0, 3.207284516819753 6.441786453757598 0, 3.207913350852247 6.441708545116405 0, 3.20858670410828 6.441502643707535 0, 3.20909311027604 6.441591682154614 0, 3.209593951540858 6.441352391328089 0, 3.209908368557105 6.441338479070733 0, 3.210222785573352 6.441191009142759 0, 3.210373037952797 6.441115882953037 0, 3.210612328779321 6.441129795210393 0, 3.210648500648447 6.441316219458963 0, 3.21067910761463 6.44146925428988 0, 3.210698584774929 6.441594464606085 0, 3.210851619605845 6.441647331184038 0, 3.211082563077956 6.441602811960498 0, 3.211268987326527 6.441694632859049 0, 3.211516625507465 6.441886622010562 0, 3.21157505698836 6.44192835878263 0, 3.211878344198722 6.441945053491457 0, 3.212039726384052 6.441936706137044 0, 3.212373620560597 6.441800366014954 0, 3.21263238854742 6.441552727834017 0, 3.212715862091557 6.441483166547236 0, 3.212697757950497 6.442439488371421 0, 3.205776272723006 6.451213609763073 0, 3.204245481 6.453176022 0)	t	[74, 89, 107]	Ojo town landing as the same similarities as Ojo Palace	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	74	107	f	f
76	2026-02-27 15:17:35.183	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Debit card/POS	Catamaran	Yes	\N	5	700	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3749219 6.4477052 0, 3.389713112398539 6.4492081354225945 0)	t	[5, 6]	Fibre boats that are not managed by Texas Connection Ferries (Monday, Wednesday, and Friday) and Sea Coach (Thursday and Mondays) operate on weekends and charge the same 700 naira. Every week, the manner of operation changes. Sea coach works twice if TCF works three times, and vice versa. On holidays, they don't work with the exception of fibre boats not under their management.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	5	6	f	t
95	2026-02-25 12:42:07.429	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	Yes	\N	150	8000	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.9752401726209143 6.577534639861369 0, 3.976508985570547 6.57634810509871 0, 4.008662465225285 6.5684511923843445 0, 4.04582355834026 6.552440451874645 0, 4.072548270835057 6.549472645810383 0, 4.075313314855073 6.547768614980537 0, 4.079252347695174 6.546255786557161 0, 4.082631106633698 6.544913148748705 0, 4.124803559549264 6.513047566237887 0, 4.173015035543756 6.423744531637354 0, 4.20884612009263 6.42831806686533 0, 4.221539839273447 6.418050827209271 0, 4.234823963996718 6.415410646404425 0, 4.2528313330658705 6.418344179787681 0, 4.2690890509226165 6.404471681473467 0, 4.280183449321754 6.403684169390516 0, 4.287833237635624 6.406769582646838 0, 4.296725989791895 6.408999852369433 0, 4.305145845720318 6.407523279318568 0, 4.3553678099030435 6.41018110773193 0, 4.532417638771761 6.386429815495447 0, 4.579859627605572 6.372128171480568 0, 4.601163695736574 6.361422887418939 0, 4.612389476363319 6.360135003905015 0, 4.61608705199032 6.357149205673082 0, 4.6271060642208965 6.33917977835209 0, 4.643350235506404 6.338434663375494 0, 4.650726543915226 6.337632095677435 0, 4.656677802104184 6.333500111492114 0, 4.662405624647988 6.3168956594825545 0, 4.6689893134388285 6.305360048881965 0, 4.671669805887049 6.296910102643203 0, 4.674969608516989 6.29079867564711 0)	f	[46, 153]	The boat leaves once a day and returns the next morning also and  gets to  Epe by 12pm. There could be stops but the officers aren't aware and those stops just depend on the passengers	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com 	46	153	f	f
128	2026-02-27 12:33:35.19	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	25	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.3897127900357433 6.449208047244448 0, 3.3978897547573017 6.438572935317076 0, 3.396733356508634 6.433144654387016 0, 3.394534485200914 6.431705742505199 0, 3.38066186993556 6.435524374355223 0, 3.376685122124744 6.433366095999907 0, 3.3713722537088104 6.431081370593191 0, 3.3688843210031942 6.430774058252066 0, 3.36749575335232 6.431184339614753 0, 3.3662025426306497 6.431784953323722 0, 3.3652027572085723 6.43254241779938 0, 3.3639865701318974 6.4336224415737755 0, 3.3629146276216098 6.4348346448196665 0, 3.3616008244369153 6.436363080765332 0, 3.3604843286442487 6.437676478675207 0, 3.359173314896516 6.439064261925379 0)	f	[6, 10]	this route is currently not active i think due to an internal situation but if it were active that would be the information needed.	Sikigha Charity	isikighacharity@gmail.com	6	10	f	f
74	2026-03-04 00:37:29.997	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	Yes	\N	30	2500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4419826471853696 6.436702621424786 0, 3.443652829220567 6.437148872682446 0, 3.4492206733569892 6.438060596948415 0, 3.4521801196018203 6.440284090899568 0, 3.452134981486707 6.442730172633206 0, 3.451558467611073 6.447846400128215 0, 3.451900657369097 6.450399148409349 0, 3.453534219879308 6.4515664124350325 0, 3.456468718333933 6.451471599300066 0, 3.459963123417252 6.45018077585767 0, 3.462956849768788 6.44993886153096 0, 3.4654748288001587 6.450956541010613 0, 3.4660678491780827 6.452015779873845 0, 3.4669495899828204 6.4543247320129 0, 3.466164974355203 6.457957823899161 0, 3.467441496144815 6.463263002624687 0, 3.4715500698139303 6.493191767178526 0, 3.5066113714975953 6.510762951724724 0, 3.553069 6.536139 0)	f	[7, 31]	\N	Israel Ekundayo	israelekundayo@gmail.com	7	31	f	f
97	2026-02-25 12:45:39.091	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	Yes	\N	60	1500	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.9752412406168105 6.577534389341622 0, 3.976279941126762 6.576101856992665 0, 4.008631272856206 6.566266959507168 0, 4.044984664456393 6.550264711797098 0, 4.070264997175144 6.546381371274705 0, 4.073688502062083 6.546786982248236 0, 4.078833697698428 6.545818903452343 0, 4.08181582205809 6.544419745770227 0, 4.086911134106316 6.538984505439771 0, 4.095291951013024 6.5307283410364505 0, 4.095193050826737 6.519404084681582 0)	f	[46, 17]	The boat leaves once a day and returns the next morning also and  gets to  Epe by 12pm.	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com 	46	17	f	f
98	2026-02-25 12:48:55.259	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	Yes	\N	20	300	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.9752393663239047 6.577533438070972 0, 3.975275479074128 6.570314483998644 0, 3.975331521760552 6.570156049365892 0, 3.975488145388397 6.569926762073607 0, 3.975568041676354 6.569710721974758 0, 3.9755929401759715 6.569503831506992 0, 3.97559441695968 6.569381310531362 0, 3.975577606299453 6.569298757767427 0, 3.975345225146924 6.567460290853333 0)	f	[46, 155]	\N	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com 	46	155	f	f
116	2026-02-27 11:02:08.795	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	135	12000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.310792342 6.437342371 0, 3.301012384192853 6.437150936171184 0, 3.2981628923134387 6.436428317908032 0, 3.2914163364721802 6.429874720711359 0, 3.283674839872091 6.429003670759495 0, 3.2788813327386195 6.427621662620133 0, 3.267630813765836 6.42766201003981 0, 3.245841069247123 6.4262228273509 0, 3.244424281781221 6.425662041439185 0, 3.243713969579543 6.416035206640465 0, 3.2384064514577107 6.4160943493428935 0, 3.231065908038463 6.411965754757007 0, 3.2238478038606075 6.406975693375611 0, 3.217619423306258 6.410321491487159 0, 3.211338158689849 6.415820710823457 0, 3.2094191172579363 6.41603977492157 0, 3.205365382756929 6.413957762632261 0, 3.2010540306941846 6.41057043586253 0, 3.1972635254741952 6.408429181567396 0, 3.1956109636745422 6.408148781188985 0, 3.192985716332245 6.408736383849566 0, 3.1863035812007303 6.413790037893613 0, 3.1813960515993873 6.4164121355151 0, 3.176481867088416 6.415087147862284 0, 3.17355340248042 6.41024568050698 0, 3.1699045841944056 6.405613513451686 0, 3.1675188181678475 6.405174562816368 0, 3.1634104690435154 6.405657144137003 0, 3.160678520524507 6.4081739241353795 0, 3.1549764732776264 6.412386431257103 0, 3.148958161564586 6.412608284952636 0, 3.138979462513017 6.410716249673231 0, 3.129707655600916 6.411432182297421 0, 3.123114630602703 6.413118918284677 0, 3.1151729611559573 6.414521483330968 0, 3.103467043658066 6.409392895256172 0, 3.095713919592437 6.407478631534756 0, 3.0822665545953467 6.410861403026502 0, 3.0757148441561224 6.410270902562877 0, 3.068360260724858 6.410058482118311 0, 3.06667207549188 6.410218208566659 0, 3.0622132680803262 6.415716270377361 0, 3.0613208326720356 6.416326466631423 0, 3.0502155667296167 6.415215797778185 0, 3.0415521824072203 6.412511958291214 0, 3.0321215648885667 6.409796830901634 0, 3.014157496828133 6.411755368879823 0, 3.006900554383551 6.41236892814087 0, 2.9856775394497967 6.406649616401365 0, 2.97871359574438 6.40803187986865 0, 2.96554384856149 6.409692048237933 0, 2.9328215319260353 6.407892255003358 0, 2.9223108961748427 6.408473400564246 0, 2.8870030113576393 6.408493606736785 0, 2.8800170928689153 6.411827319258985 0, 2.8779216840909934 6.4133337648634585 0, 2.8760105054596723 6.41595476406292 0, 2.8576852568033555 6.424639249359496 0, 2.8342525232164486 6.4401893185105195 0, 2.8204050865376207 6.4518529537357505 0, 2.799813196089708 6.459266365361081 0, 2.790994814400415 6.457310984803258 0, 2.7850421223125013 6.452369708092357 0, 2.7814308984693117 6.450986677878642 0, 2.7709802227103912 6.449654155895667 0, 2.751254943421838 6.4460157858833265 0, 2.743791751574156 6.4486071702606775 0, 2.728272025827958 6.458525520123992 0, 2.716512469723355 6.457266445714334 0, 2.7093778596894564 6.453536207425856 0, 2.6912220188207496 6.444312362442058 0, 2.6722552261475894 6.4421429271230775 0, 2.6636662325480613 6.444628285543086 0, 2.644469056143989 6.456944455637746 0, 2.627955613354965 6.462329938049392 0, 2.6233855442023355 6.466004874097848 0)	t	[92, 13, 4]	This route form covers for jegba marina badagry and port novo as often times,there are usually not even paasengers for jegba marina so they merge them up with pople heading to port novo, they do a stopover at jegba marina,pick up likely passengers for port novo too as well 	Sikigha Charity	isikighacharity@gmail.com	92	4	f	f
129	2026-02-28 16:26:03.722	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat, Wooden boats, Covered	Yes	Yes	25	700	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.389713363422642 6.449207443011608 0, 3.397024980225046 6.438368685397062 0, 3.3943843699884138 6.432112345460199 0, 3.3863233418099252 6.433664828762231 0, 3.3807906420568203 6.435113421178119 0, 3.376980912818123 6.432749313530195 0)	f	[6, 121]	\N	Israel Ekundayo	israelekundayo@gmail.com	6	121	f	f
33	2026-02-09 14:52:56.801	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	20	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.23667811 6.437043497 0, 3.235353134 6.428563414 0)	f	[18, 80]	\N	Mr olayinka	olayinkamubo26@gmail.com	18	80	f	f
109	2026-02-25 20:57:55.139	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	20	1200	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.310792342 6.437342371 0, 3.314447678953428 6.435188556554522 0, 3.3176795430389916 6.433451695939439 0, 3.3185759439852234 6.433095393408948 0, 3.3197910652698113 6.432699501415698 0, 3.3200148676967274 6.433340200810306 0, 3.31541941035141 6.445828594321938 0, 3.312939475722544 6.452056391271142 0, 3.3108338195200133 6.455180912040234 0, 3.3077366 6.4590664 0)	f	[92, 101]	stopovers along thia route are ijegun egba, coconut landing and ibasa but they arent common.	Sikigha Charity	isikighacharity@gmail.com	92	101	f	f
123	2026-02-27 12:04:26.134	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	20	1200	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.310792342 6.437342371 0, 3.2971994417888197 6.437286089914082 0, 3.2920349163277365 6.431208105406398 0, 3.277015963970058 6.428629041809714 0, 3.258691 6.427831 0)	f	[92, 70]	\N	Sikigha Charity	isikighacharity@gmail.com	92	70	f	f
124	2026-02-27 12:18:06.783	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	40	2500	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.389713112398539 6.4492081354225945 0, 3.3829119525782945 6.451441065088071 0, 3.3803861322979474 6.453366833190138 0, 3.3791850480808168 6.456900041837391 0, 3.379395913126663 6.462072672798968 0, 3.382478301866796 6.462734506635153 0, 3.4022407735552744 6.490156416189616 0, 3.428253364310632 6.521228500367762 0, 3.4509714376522256 6.553069866619464 0, 3.475611217092661 6.58944681990172 0, 3.4862304 6.601832 0)	t	[6, 1, 3]	\N	Sikigha Charity	isikighacharity@gmail.com	6	3	f	t
132	2026-02-27 15:05:21.084	Informal Commercial: Operated by unlicensed operators (NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	Yes	\N	7	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.349851834 6.446059237 0, 3.349289318 6.44263934 0)	f	[102, 104]	They work on public holidays. They close by 10:00 pm, but they give a grace of 15 minutes to passengers. No life jackets worn by passengers. Passengers stand in these boats. They are under The Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON). Peak Times: 5am - 9am, 5pm - 7pm.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	102	104	f	f
172	2026-03-30 15:14:50.733875	LagFerry/Government: Operated by the government	Cowry card	Catamaran	\N	\N	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.553069 6.536139 0, 3.470635686121085 6.4940117930292445 0, 3.4670143680869216 6.462439588998464 0, 3.4667549792819727 6.448935778983639 0, 3.464132750036356 6.44819240074419 0, 3.4617355754291452 6.44813475857184 0, 3.4560515286549673 6.44997107976539 0, 3.4534055068806992 6.4494285310141635 0, 3.453651565085835 6.442977443346365 0, 3.453457064738103 6.4410298536526795 0, 3.4533224106516514 6.44058383969417 0, 3.4527443718940845 6.439919633225514 0, 3.449457862235903 6.4374865430526 0, 3.443717301000845 6.436883529920593 0, 3.4419823237827245 6.436702845603293 0, 3.4400464892414675 6.438523240434364 0, 3.4358257070941676 6.441307761165696 0, 3.4356474122120346 6.441361655582341 0, 3.4296359596264665 6.441545575929794 0, 3.427179994 6.442095174 0)	t	[31, 96, 7, 2]	future omi eko	Fisayo 	fisayo@publictech.studio	31	2	f	t
11	2026-01-13 00:00:00	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Speed boats,Covered	Yes	\N	30	3000	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4862304 6.601832 0, 3.479069999449163 6.583197125644056 0, 3.4581636073752415 6.545330109131676 0, 3.465460092042102 6.46082718324549 0, 3.4653099 6.4571785 0, 3.46576111763656 6.454041859593162 0, 3.466385921371633 6.452362699555154 0, 3.466307820904749 6.450995941384682 0, 3.463141810297893 6.44930069898646 0, 3.4590768 6.4475959 0, 3.458359966976963 6.448883236474314 0, 3.457373237402803 6.449832014911006 0, 3.456709092497118 6.450173575148216 0, 3.455817240766628 6.45043923311049 0, 3.45469768221133 6.45043923311049 0, 3.453710952637171 6.450097672873281 0, 3.452970905456551 6.449680210361136 0, 3.452970905456551 6.448484749530904 0, 3.453236563418824 6.444461928959328 0, 3.453046807731486 6.44229871412367 0, 3.4529322404580616 6.439860672772989 0, 3.4495531366733756 6.437336068493657 0, 3.4437203120600492 6.436806387015445 0, 3.441982189645216 6.4367026539256464 0, 3.4401041221520017 6.438592865332013 0, 3.435869985424152 6.4414333800114045 0, 3.4356621818033526 6.441495609665203 0, 3.4296514397628646 6.441618604873687 0, 3.427179994 6.442095174 0)	t	[3, 12, 7, 2]	\N	Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	3	2	f	f
94	2026-02-25 10:04:53.357	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	Yes	\N	2	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.628719474857945 6.500699929759122 0, 3.6269291891281625 6.502267038329876 0)	f	[86, 152]	This is a route used for crossing...about 250m long 	Fisayo 	Fisayo@publictech.studio	86	152	f	f
142	2026-02-27 22:04:15.033	Informal Commercial: Operated by unlicensed operators (NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	Yes	Yes	5	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.349967622024593 6.446357951829157 0, 3.3504457669607746 6.446066939630768 0)	f	[149, 151]	They work on public holidays. They close by 10:00 pm, but they give a grace of 15 minutes to passengers. No life jackets worn by passengers. Passengers stand in these boats. They are under The Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON).	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	149	151	f	f
54	2026-02-13 10:37:31.148	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	No	Yes	3	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.1734943722962328 6.510683889386883 0, 3.1736089675958397 6.511395593906656 0, 3.173427594649553 6.51223326638268 0, 3.1727851181964297 6.51282389610077 0, 3.1722341504553384 6.5127828485961174 0, 3.1717475842150122 6.5128353189245445 0, 3.170502605137642 6.514279431457879 0)	f	[83, 142]	In the mornings, Iteku to Isashi has high movement and in the evenings, Isashi to Iteku has high movement.	Mr Amodu Falilu	Amoduoluwafemi64@yahoo.com	83	142	f	f
44	2026-02-11 10:44:11.843	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Wooden boats	No	Yes	7	400	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.206458960639196 6.552217147901231 0, 3.2062347756607608 6.552213098433981 0, 3.206059503767648 6.552124010159659 0, 3.2056029816294824 6.55193368515684 0, 3.204852980973868 6.551524688629527 0, 3.2047388504396395 6.551459897068909 0, 3.2045105893699883 6.551427501286014 0, 3.203654610360246 6.551322214976821 0, 3.2034548819255804 6.5513262644502674 0, 3.2032877622137335 6.551743360082554 0, 3.2032429252184613 6.552484412625574 0, 3.2033896644772994 6.552889358907208 0, 3.2033652079346098 6.553261909194447 0, 3.2030146641494923 6.553440085320744 0, 3.2027401962956787 6.553619978736052 0, 3.2022080220690157 6.553702106376321 0, 3.201732681983799 6.553619978736052 0, 3.201407177360693 6.553619978736052 0, 3.2011075064365 6.553738037213179 0, 3.200689000492673 6.553804765906563 0, 3.2001516595265684 6.553491654272349 0, 3.1996021235747776 6.553186138152498 0, 3.199435727309236 6.553092886862487 0, 3.199273597615388 6.552800416795847 0, 3.1990560024988497 6.552618152753212 0, 3.1983477517289884 6.5523765468276025 0)	f	[63, 145]	Destination is Totowu Odo. Bank transfer is allowed but inform the boat operator before entering the boat	Mr Komolafe Michael	komolafetemitope5555@gmail.com	63	145	f	f
96	2026-02-25 12:43:55.983	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	Yes	\N	110	3500	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.9752417844242984 6.577535064325261 0, 3.9767763661495223 6.576648940218519 0, 4.010187516126621 6.571469043395766 0, 4.04619328109996 6.553444550003405 0, 4.072791255530234 6.550536682173345 0, 4.0772989399326605 6.547770384694019 0, 4.098672316381027 6.53873156286474 0, 4.187126458946139 6.523173256870649 0, 4.192336731520612 6.5182992422275134 0)	f	[46, 154]	The boat leaves once a day and returns the next morning also and  gets to  Epe by 12pm. There could be stops but the officers aren't aware and those stops just depend on the passengers	Mr Oshodi Ismail	Ismailolamijioshodi@gmail.com 	46	154	f	f
144	2026-02-27 21:57:52.43	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	Yes	\N	150	12000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.307735846940261 6.4590668022350854 0, 3.3127111454147666 6.453047768931935 0, 3.320459574526552 6.432309690110181 0, 3.3047851231092977 6.4382301264844735 0, 3.2983289814638823 6.437337024123646 0, 3.291841436739169 6.430412595481995 0, 3.2815324096476104 6.428514132883409 0, 3.246329820881982 6.426046878441184 0, 3.235578729662734 6.429448358626601 0, 3.2282634183255965 6.43326142368101 0, 3.2202456519385407 6.436028054081618 0, 3.21222094984644 6.4349916973920145 0, 3.2050595725933704 6.4341944103398845 0, 3.195381585688864 6.4372642785559435 0, 3.1897964932556704 6.43497874091122 0, 3.1874897231375456 6.434280117812456 0, 3.184856733715378 6.435156845742 0, 3.178323249636776 6.438504227835423 0, 3.1754834083642933 6.439972951567899 0, 3.1727323614509686 6.441193588891046 0, 3.168777071899086 6.441077341547398 0, 3.1665269747928164 6.439720362532441 0, 3.164870027719502 6.437896179811801 0, 3.161739029546524 6.4293480168512005 0, 3.1598732547167927 6.42708557743256 0, 3.1560191354376173 6.424882042167567 0, 3.1526299015946506 6.423738917675962 0, 3.149760565379097 6.420939990137498 0, 3.14729342821191 6.420745602878942 0, 3.1451382610307235 6.421615846186434 0, 3.1437432685611952 6.422638858090394 0, 3.141458923390715 6.424975119284884 0, 3.1349121352745613 6.428145900111822 0, 3.1300209719780128 6.427610692681796 0, 3.119656118248983 6.426448439913088 0, 3.1159692483787182 6.427252000210899 0, 3.112282080846825 6.427366902666819 0, 3.1093544512542053 6.425508642567451 0, 3.1075275611294444 6.421990966542964 0, 3.107116623591807 6.416177966973166 0, 3.1058338031690766 6.410054944291247 0, 3.1013998309408493 6.4072274477246935 0, 3.094804577745947 6.406264267306227 0, 3.0822872911037678 6.409858520690349 0, 3.0673317414569397 6.409540974572764 0, 3.0623464996904204 6.410374666391732 0, 3.051715055378139 6.414721941561936 0, 3.0479952157908485 6.413729110889079 0, 3.036898213836537 6.409224605614227 0, 3.026736637051407 6.405917177824513 0, 3.025041216661567 6.405206501077533 0, 3.024008833249482 6.405239843183281 0, 3.0177777346514176 6.406594803375384 0, 3.0115397858750015 6.4111589610039985 0, 3.0074952409685523 6.411395064853153 0, 2.9856568866621416 6.405788677768186 0, 2.97899623409387 6.407045197999523 0, 2.9655888535810817 6.408877895636543 0, 2.953234938227382 6.407957680818782 0, 2.9423050638166757 6.407797019564583 0, 2.9335830661980253 6.407383959615686 0, 2.921599823213569 6.4077731820107005 0, 2.898810750980884 6.406592105794915 0, 2.8866112461523246 6.407406281284688 0, 2.884060352224278 6.408045858744133 0, 2.875828066632275 6.414208329261139 0, 2.8660648225610075 6.41838718070149 0, 2.8555185981304163 6.4231538644120505 0, 2.850434867589854 6.426353817218086 0, 2.8320277104967193 6.439063195541099 0, 2.81881078061625 6.450269473874904 0, 2.807563830195525 6.45440341632035 0, 2.799331777242436 6.455652382889639 0, 2.7931598129061825 6.453862435780465 0, 2.7833930810137986 6.448569106621335 0, 2.7497355998113733 6.443121075623324 0, 2.742216392185753 6.445899524540508 0, 2.73617632500698 6.451070910578906 0, 2.72802144129912 6.456120762575694 0, 2.7175419370011014 6.455388317218592 0, 2.7082451392772384 6.450031985772 0, 2.706729443309257 6.4472791217291245 0, 2.7065856763532565 6.447039531909624 0, 2.7065227860957464 6.446816015105199 0, 2.706607622503114 6.446484571452153 0, 2.706711869319463 6.446178844702672 0, 2.7068955274947655 6.445212259346974 0, 2.706949547333565 6.445076529112484 0, 2.7070872696031714 6.444979356546185 0, 2.7073290639538925 6.444911730937335 0, 2.707960851256587 6.444710753446131 0, 2.707343174956904 6.4448563011833855 0, 2.706943554442404 6.444977226448856 0, 2.706855015905937 6.445106566851948 0, 2.7068017358441665 6.445270463663974 0, 2.7066261055482244 6.446353253271894 0, 2.7056627600537695 6.449032010901362 0, 2.7043788493037866 6.449257765078823 0, 2.6907990958325883 6.445316830434244 0, 2.672308668083872 6.443077064182987 0, 2.6640536458694726 6.445507892901368 0, 2.6445623636921596 6.457325458170359 0, 2.6282654644694503 6.462716872282023 0, 2.62338128823194 6.465995687572757 0)	t	[101, 139, 4]	\N	Israel Ekundayo	israelekundayo@gmail.com	101	4	f	f
148	2026-02-28 00:25:18.503	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana	Yes	\N	52	2000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	LineString Z (3.261648271553033 6.407551828228942 0, 3.247655434719591 6.4123980184837635 0, 3.2381120812881194 6.417631045265343 0, 3.2365837449062225 6.417414091167817 0, 3.2237268041425375 6.407223917048471 0, 3.2104669740911254 6.408614832281238 0, 3.205551786969208 6.406651958343591 0, 3.212965728872917 6.414245767461447 0, 3.210824404637061 6.415927806687773 0, 3.2074984715131776 6.415971707178945 0, 3.199419475461721 6.416346762494447 0, 3.1990057328668655 6.417367093332628 0, 3.198753850037465 6.4185382067447 0, 3.1993084065809607 6.419539060415695 0, 3.1989498692047227 6.421862519723986 0, 3.199341777141711 6.425125650963817 0, 3.1994380185557665 6.426958699751105 0, 3.199255843590292 6.430644201964959 0, 3.199198168707534 6.431818591734833 0, 3.199359806428408 6.43273181328109 0, 3.1997841869184964 6.433438748806801 0, 3.199862008680047 6.434339149052009 0, 3.199637886847143 6.435235636383625 0, 3.199541834633042 6.435795940965884 0, 3.199493808525991 6.436292210738742 0, 3.199509817228341 6.436724445702199 0, 3.199729685962439 6.437172448732188 0, 3.200908287509451 6.437481633442951 0, 3.201913346068144 6.437750730276349 0, 3.202000121152798 6.437775849379801 0, 3.202024113888362 6.437928089527067 0, 3.202069670598982 6.438179991338727 0, 3.202058903121032 6.438353316713476 0, 3.202044064682965 6.438582941520941 0, 3.202036314949733 6.438634797642549 0, 3.202039905356677 6.438649159270327 0, 3.202198301311318 6.439096485164126 0, 3.202503799253118 6.439329628330236 0, 3.202661907837032 6.439444860010037 0, 3.202744981838749 6.439503815753192 0, 3.202761060677791 6.439535973431276 0, 3.202806617388411 6.43958688975491 0, 3.202875950657815 6.439673585476046 0, 3.202975839514171 6.439782976171497 0, 3.203059773057337 6.439859522026505 0, 3.203113913993497 6.439907346520113 0, 3.203237227199949 6.440017658768764 0, 3.203253334768289 6.440049067511061 0, 3.203245732158587 6.440090881864421 0, 3.203238129548885 6.440241033406033 0, 3.203245244736249 6.440290040379391 0, 3.203231298490174 6.440395633385391 0, 3.203251221698853 6.440503218712259 0, 3.203299037399683 6.440680535269504 0, 3.203332906854437 6.440841913259805 0, 3.203358807025721 6.440997314287503 0, 3.203386699517871 6.441130799785653 0, 3.203392676480475 6.441178615486484 0, 3.203600712149039 6.441268060756738 0, 3.203789150136757 6.441369527365509 0, 3.203948121293879 6.441414821457691 0, 3.204284140759996 6.441714184254777 0, 3.204772896347075 6.442053258443313 0, 3.205050876087226 6.442248760678145 0, 3.205310527492861 6.442374004297332 0, 3.205686258350428 6.442386223187009 0, 3.205793173635101 6.442395387354266 0, 3.206031441983802 6.44230374568169 0, 3.206275819777342 6.442205994564274 0, 3.206556854239912 6.442025765941538 0, 3.206682097859101 6.44193717899138 0, 3.206819560367967 6.441900522322349 0, 3.206950397050636 6.441885829688987 0, 3.206969564269626 6.441954138394951 0, 3.207009122147109 6.442053848715006 0, 3.207031959684626 6.442169667655271 0, 3.207031959684626 6.442796068684314 0, 3.207035222189985 6.443091325419357 0, 3.206911246986321 6.443469776041071 0, 3.206503086279182 6.443779603272752 0, 3.206527535520412 6.443884385735166 0, 3.206611361490344 6.444041559428788 0, 3.206754564188978 6.444432747288471 0, 3.206804225996699 6.444706080161613 0, 3.206851403287831 6.445215594905838 0, 3.206874991933397 6.445489223194404 0, 3.20701180607768 6.446017608855081 0, 3.207073136556152 6.446220471206949 0, 3.207058983368812 6.446451639933496 0, 3.207021241535907 6.446734703680288 0, 3.206286535856859 6.447691481869566 0, 3.204691272048581 6.451306611466339 0, 3.204245472039803 6.453176016321364 0)	t	[60, 73, 74, 77, 89, 107]	this route is usually not busy, somedays, they might not be any boat going from ibese to ojo, the route is mostly active on market days, or when activities are taking place in villages along the route. 	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	60	107	f	f
178	2026-03-30 15:33:55.359817	LagFerry/Government: Operated by the government	Cowry card	Covered	\N	\N	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3592365 6.4390793 0, 3.3591390606942184 6.439055181722111 0, 3.356790495616451 6.4394043088887685 0, 3.3562726486253496 6.439442944625725 0, 3.352406090320386 6.438069736999111 0, 3.349015674309726 6.436700208806855 0, 3.34748125839144 6.436280219421377 0, 3.346589701046696 6.4360166106982035 0, 3.338916324364874 6.437517919849384 0, 3.3376170169954946 6.437710050001158 0, 3.335847395427095 6.437931362805159 0, 3.328428304150833 6.4361255512379785 0, 3.321411545369159 6.4323353946241895 0, 3.31770318655785 6.440676872929799 0, 3.3126998346792504 6.452178670080443 0, 3.308164031620805 6.458315000701006 0, 3.30773634763824 6.459065698603084 0, 3.306508347164794 6.459825735611815 0, 3.3047168309146855 6.461086403919552 0, 3.300718448995724 6.4638672039777845 0, 3.298498460159891 6.46761205016773 0, 3.294500326844343 6.474222765687571 0, 3.294149195 6.474484688 0)	t	[10, 38, 101, 36]	future omi eko	Fisayo 	fisayo@publictech.studio	10	36	f	t
161	2026-03-04 00:39:44.239	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	Yes	\N	35	2500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4419826471853696 6.436702621424786 0, 3.443666992206885 6.4372288397857576 0, 3.445986728202562 6.4376495934942195 0, 3.449117725432145 6.438303588965708 0, 3.4519715829444886 6.440393665550367 0, 3.4516980694723083 6.445765613932169 0, 3.4519879085322343 6.449272062603984 0, 3.4539006747649443 6.4508381434881175 0, 3.4563640169388448 6.450812689283228 0, 3.4599805736491462 6.44936580598782 0, 3.4648763753588563 6.448967832990185 0, 3.468179614859655 6.4497600972135425 0, 3.4683538296537875 6.450940716805418 0, 3.4676824997552016 6.454550147134576 0, 3.467615067431248 6.459921802258204 0, 3.468415474020915 6.4650988191676655 0, 3.4722858794872256 6.492278408933654 0, 3.5344788628666293 6.521080293664063 0, 3.566467854961183 6.537885027284704 0, 3.5890471 6.5632172 0)	f	[7, 69]	\N	Israel Ekundayo	israelekundayo@gmail.com	7	69	f	f
173	2026-03-30 15:17:22.0987	LagFerry/Government: Operated by the government	Cowry card	Catamaran	\N	\N	9999	1	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4862304 6.601832 0, 3.476071390806169 6.591588911342527 0, 3.472009614575626 6.587939990538821 0, 3.4321890529887185 6.535912121983031 0, 3.400905291241486 6.492415447606703 0, 3.3858497276988544 6.470452067537273 0, 3.3811658412014935 6.4658432427404335 0, 3.3753125028239026 6.460423828807869 0, 3.3733754684188284 6.451761547864606 0, 3.3749802836868525 6.447537509135387 0, 3.376052535935173 6.447555329428127 0, 3.39645782860282 6.438159873720281 0, 3.3963400001297828 6.437475697441286 0, 3.393868106762085 6.433247586067935 0, 3.3816394372364584 6.436801277022511 0, 3.380889602967528 6.436932766546306 0, 3.380330902924811 6.436874326762407 0, 3.370142999927623 6.43226229786319 0, 3.3692547814365525 6.432013351682997 0, 3.367979390782665 6.431900194287962 0, 3.365360284976049 6.432986504241228 0, 3.362998672444931 6.435090410683706 0, 3.3592365 6.4390793 0)	t	[3, 5, 10]	future omi eko	Fisayo 	fisayo@publictech.studio	3	10	f	t
126	2026-02-28 15:56:43.238	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	Yes	\N	180	11000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3897130724147204 6.449208131096859 0, 3.398971961242275 6.438821049750033 0, 3.397594880817161 6.4325293289408085 0, 3.397088152753828 6.432283950630482 0, 3.39462452107935 6.431037975990516 0, 3.392245842221233 6.431576010494137 0, 3.382051504257875 6.434719264699504 0, 3.380069271876112 6.43437945343406 0, 3.37652957119439 6.433105161188641 0, 3.372536788825408 6.431774233732313 0, 3.370582874049098 6.431122928806876 0, 3.369153149403982 6.431123457652282 0, 3.367677414957439 6.431356468354367 0, 3.365632098794687 6.43228851116271 0, 3.363768013178001 6.433712465453234 0, 3.358922820165902 6.438092045342704 0, 3.357640533630135 6.438569175216478 0, 3.354270803896606 6.438360430896702 0, 3.349529325775977 6.436183525847608 0, 3.34791901245199 6.435438010419836 0, 3.343985 6.435955 0, 3.338853544850284 6.4372570680636 0, 3.337054 6.437405 0, 3.33279452955396 6.436830024957669 0, 3.326403006958785 6.433792654161712 0, 3.322937050099593 6.43144474790226 0, 3.320197826130233 6.430829820072403 0, 3.313766733426001 6.435512057257997 0, 3.306203559456832 6.437035000900955 0, 3.303147554484212 6.437072269254279 0, 3.300948721638059 6.436923195840981 0, 3.298799517862232 6.43660544945724 0, 3.2916490105314 6.429566440034639 0, 3.287289870144581 6.429618598589352 0, 3.283674839872091 6.429003670759495 0, 3.280432493132848 6.427904254336418 0, 3.272680675641324 6.427811083453108 0, 3.267630813765836 6.42766201003981 0, 3.261582442901189 6.426998119802293 0, 3.252524553298327 6.426664550290312 0, 3.248607237065779 6.426552881465626 0, 3.245841069247123 6.4262228273509 0, 3.244913774353368 6.426065658724839 0, 3.244424281781221 6.425662041439185 0, 3.24373258202002 6.419878321268829 0, 3.243802899807445 6.41805005879578 0, 3.243662264232595 6.416292114110155 0, 3.24317003972062 6.416116319641592 0, 3.241271459460145 6.416327273003867 0, 3.238716683536926 6.416454019706714 0, 3.231065908038463 6.411965754757007 0, 3.223579895291138 6.406975693375611 0, 3.2173567406293677 6.409264430958138 0, 3.210849599584269 6.41442065080506 0, 3.211160141956838 6.415321223685508 0, 3.210694328397985 6.41578703724436 0, 3.207771162265023 6.415315978560096 0, 3.202870395278649 6.411943097751826 0, 3.198335880855896 6.408018452032906 0, 3.194838681717854 6.406538867782197 0, 3.186506896029426 6.414059427529772 0, 3.181751816119032 6.416600935757741 0, 3.179538244436606 6.416272999212198 0, 3.176176894844776 6.415289189575564 0, 3.17355340248042 6.410616093801556 0, 3.1698596509959014 6.405844594348748 0, 3.167661273383476 6.405402512179813 0, 3.1635328128022575 6.406034526070403 0, 3.1612356378799196 6.408354259246833 0, 3.156008797293792 6.412583713074822 0, 3.148958161564586 6.413239586165911 0, 3.139038081061866 6.411107998619872 0, 3.1318682392283876 6.411740533509803 0, 3.127402345473034 6.41232377232884 0, 3.123952999966821 6.413567522711456 0, 3.1151287291804635 6.415343558831149 0, 3.1046457358478916 6.410698077937942 0, 3.095586488777226 6.407828633164428 0, 3.0914576367414024 6.409506616587763 0, 3.08232262643776 6.412035461391685 0, 3.0755171732157294 6.410675850284147 0, 3.0681668932969184 6.410219385476486 0, 3.066750893634718 6.410698807270549 0, 3.061421279936694 6.416953284034209 0, 3.054531915720074 6.4166672044416 0, 3.050153878245607 6.415874199676249 0, 3.040965439330127 6.413145664162473 0, 3.0313372605821454 6.410442572663591 0, 3.020997709651777 6.411702828704332 0, 3.006657690248917 6.412930825161089 0, 2.9858331966701153 6.407136772451542 0, 2.979197107426244 6.408637212800576 0, 2.9654266874709467 6.410058483781673 0, 2.933620397751267 6.408213151911409 0, 2.922354008593367 6.408730458664676 0, 2.90964646745352 6.409058395210221 0, 2.886830561682122 6.408922036867496 0, 2.8799849778348556 6.412055054618757 0, 2.8780304103025722 6.413513588082018 0, 2.8760105054596723 6.41595476406292 0, 2.8576369838953095 6.424034819479056 0, 2.833185594405719 6.439654843270901 0, 2.8197506891227153 6.451503190121583 0, 2.799815528248449 6.457746727321793 0, 2.791787176712253 6.456478157892567 0, 2.785729861105501 6.451753515570637 0, 2.7812985146867266 6.45019944030771 0, 2.750939942494437 6.444768082624926 0, 2.743059411911793 6.4474444502276835 0, 2.735076844301304 6.453534151386544 0, 2.728325453582707 6.4575605534009926 0, 2.7168586561255976 6.456554596665583 0, 2.707214649311322 6.451383833322391 0, 2.7038499363420296 6.446469234850715 0, 2.691585858689828 6.4426813791823 0, 2.6724526460197495 6.440120632078483 0, 2.663031831897504 6.443143727181427 0, 2.645037526638773 6.455567596805501 0, 2.627239995573462 6.461353308980332 0, 2.623381052619242 6.466000568427495 0)	t	[6, 13, 4]	\N	Israel Ekundayo	israelekundayo@gmail.com	6	4	f	f
122	2026-02-27 11:40:55.67	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	30	2500	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.294149195 6.474484688 0, 3.3011003803102597 6.464445257871361 0, 3.305334755480331 6.461348636245084 0, 3.3079572365272725 6.458465568655328 0, 3.3142536113504946 6.449762960521042 0, 3.3204553038454776 6.432545468690307 0, 3.320939417466178 6.4322864990606945 0, 3.321711430196558 6.431723919977344 0, 3.334211333720191 6.437229029714715 0, 3.3461887463602693 6.435567565285879 0, 3.356042081048116 6.439109066799276 0, 3.359173433733389 6.439064280470035 0, 3.3641286088483184 6.432232669755621 0, 3.3592365 6.4390793 0)	t	[36,121,10]	\N	Sikigha Charity	isikighacharity@gmail.com	36	10	f	f
181	2026-04-21 10:10:29.107116	Informal Commercial: Operated by unlicensed operators (NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	Yes	\N	8	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.280752801 6.430224369 0, 3.280746 6.426853 0)	f	[79, 222]	\N	Fisayo Balogun	fisayo@publictech.studio	79	222	f	f
163	2026-03-05 03:24:07.114	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats, Fibre boat	Yes	\N	5	200	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.352172281143254 6.424158024591193 0, 3.3477647193057862 6.426330269704778 0)	f	[64, 84]	\N	Israel Ekundayo	israelekundayo@gmail.com	64	84	f	f
66	2026-02-18 21:34:05.46	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Wooden boats, Banana	Yes	\N	15	1000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats are suspended.	LineString Z (3.19931338 6.419640776 0, 3.199145397220724 6.421984536069804 0, 3.1994061425901195 6.424433993276074 0, 3.1996964344306136 6.426186215415105 0, 3.199831389667562 6.427118715176602 0, 3.19972491649118 6.428989972296103 0, 3.1996258983773553 6.430107030285126 0, 3.199568934256252 6.431773806246719 0, 3.1995899612521272 6.432273968057532 0, 3.1998971470515216 6.432792902819451 0, 3.200119527116382 6.43328055951541 0, 3.1999301450223365 6.43436575253427 0, 3.1995728505905525 6.435899236061808 0, 3.1995528247939005 6.436116945457069 0, 3.19953270233641 6.436394448350841 0, 3.199539515110127 6.436714755539769 0, 3.1996372914716216 6.436916116108734 0, 3.199753767484294 6.437164520919091 0, 3.200908287509451 6.437473705629854 0, 3.201841414090075 6.437725611172897 0, 3.201979569159064 6.437763289828076 0, 3.202003546485087 6.437771282270083 0, 3.202013822481954 6.437815811589839 0, 3.202025543728899 6.437908338637405 0, 3.202040231978898 6.437989758975746 0, 3.202073415821495 6.438177619158258 0, 3.202061147197785 6.43839969429971 0, 3.202046015263568 6.438603747714049 0, 3.202041463908826 6.438630405648967 0, 3.20204119368395 6.43863735792205 0, 3.202048529448984 6.438659930491162 0, 3.202137092820286 6.438914849384235 0, 3.20220137017026 6.439094667522329 0, 3.202367316731634 6.439220687091494 0, 3.2025694471297 6.439372908749296 0, 3.202749661875542 6.439503580264954 0, 3.20276296644252 6.439528288746485 0, 3.202877005588047 6.439668937025969 0, 3.202975839514171 6.439777274214221 0, 3.203241930853736 6.440011054462552 0, 3.20325713607314 6.440041464901359 0, 3.203257198661456 6.440088815971731 0, 3.203243252415381 6.440246209320297 0, 3.203251221698853 6.440298009662863 0, 3.203237275452777 6.440395633385391 0, 3.203259190982324 6.440515172637467 0, 3.203295052757947 6.440640688852145 0, 3.203348845421381 6.440889728960635 0, 3.203362791667456 6.440989345004031 0, 3.203398271258415 6.441176553108988 0, 3.20355221137117 6.441240055540959 0, 3.203706798222758 6.441317070340274 0, 3.203786221005659 6.441362891176562 0, 3.203957285461136 6.44140871201285 0, 3.204039762966456 6.441488134795751 0, 3.204253593535803 6.441677527585744 0, 3.204284140759995 6.441708074809936 0, 3.205017274140613 6.442215158731531 0, 3.205060040254483 6.442245705955723 0, 3.20531221154695 6.442361951564902 0, 3.205798324845531 6.44238478910242 0, 3.206247327145644 6.442213711477624 0, 3.206470400949608 6.442074851093258 0, 3.206679201292622 6.441928038352076 0, 3.206836643784536 6.441890899387729 0, 3.206992809620311 6.441871148414869 0, 3.207012384652468 6.441926611005981 0, 3.207075897073717 6.442316141547694 0, 3.207071109748941 6.442645993437772 0, 3.207054940581234 6.443213777975713 0, 3.206943172621324 6.443489705126738 0, 3.206621839736585 6.443741183036533 0, 3.206558970259136 6.44379357426774 0, 3.206649781726563 6.444010124690065 0, 3.206754564188978 6.444331457574803 0, 3.206831404661415 6.444673746952025 0, 3.20689386284985 6.445361844508347 0, 3.207007088348567 6.445777004670308 0, 3.207082572014378 6.446196882561384 0, 3.20711559611817 6.446588454077779 0, 3.207073136556152 6.44676772778408 0, 3.206728742330888 6.447220629778947 0, 3.206549468624587 6.44746123396372 0, 3.206454187796723 6.447677510874578 0, 3.205581656519368 6.449548102136533 0, 3.204891608554508 6.451273222048684 0, 3.204245481 6.453176022 0)	f	[89, 107]	This route is mostly busy in the early morning, when market people are going to trade, in the afternoon to late evenings there is scanty activities	Kokodoko Victor Ayomide	Kokosvictorayomide@gmail.com	89	107	f	f
149	2026-02-28 14:41:07.223	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	Yes	Yes	3	100	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.362453877 6.418094084 0, 3.3588530258308253 6.417626165505482 0)	f	[129, 24]	Most boat operators might refuse to carry you as it is approximately a five minute walk from Itomoro. They would encourage you to trek it.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	129	24	f	f
17	2026-02-09 10:57:15.008	LagFerry/Government: Operated by the government	Cowry card	Covered	Yes	\N	45	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.359173020483679 6.439063929145328 0, 3.362292278731458 6.435667166342952 0, 3.364052804036106 6.433595960102191 0, 3.364661220869329 6.433194663893043 0, 3.365114297234496 6.433000488307972 0, 3.36545086824862 6.432767477605887 0, 3.366344075939948 6.432275566123705 0, 3.367004272929191 6.432029610382615 0, 3.368195216517629 6.431680094329487 0, 3.370331147953415 6.431563588978443 0, 3.37140558619081 6.431848379836548 0, 3.375793313452592 6.433473290059539 0, 3.381315246516077 6.43528561680858 0, 3.387686707743176 6.4335582428759 0, 3.394596203473896 6.431406104861413 0, 3.3971791842365153 6.433119215609712 0, 3.398499957838382 6.438607102664451 0, 3.3897126633874217 6.449208114885105 0, 3.3986144746746314 6.4422428670775735 0, 3.4013770107537047 6.439913772187001 0, 3.401889597480791 6.439538831803817 0, 3.402215553399695 6.439365821095312 0, 3.4024311545771213 6.439403763518911 0, 3.4030431812002355 6.440089256695017 0, 3.404848856056453 6.441820315752079 0, 3.40597988011192 6.442015648412774 0, 3.407969011976958 6.442045971400944 0, 3.4108889186863904 6.441082862901814 0, 3.4160541162147204 6.43846648329669 0, 3.4181928607335674 6.438109153269481 0, 3.42178772471214 6.439098175880853 0, 3.425017651544929 6.441035265795154 0, 3.427175929330542 6.442095819404855 0, 3.4303753248264597 6.44188397758475 0, 3.435703490775111 6.441937450564477 0, 3.4371147390907995 6.441297643069623 0, 3.439745028102815 6.440005894699184 0, 3.443204916649234 6.437825499151374 0, 3.4452220458414486 6.43768592593405 0, 3.448906466453445 6.438654957592255 0, 3.451668881769882 6.440445613165541 0, 3.452305327720838 6.440872262549842 0, 3.452762174200478 6.443759832916176 0, 3.452591394081874 6.449338650123927 0, 3.452667296356809 6.450021770598346 0, 3.453426319106163 6.450382306404288 0, 3.454242268561718 6.450742842210231 0, 3.455741338491692 6.450799768916433 0, 3.457088603871795 6.450458208679223 0, 3.458511771526834 6.449737137067338 0, 3.460371377262751 6.44886426090558 0, 3.464109564303319 6.448484749530905 0, 3.46841653351062 6.449394881813557 0, 3.46880703584504 6.450683539517145 0, 3.468572734444388 6.452128398154501 0, 3.468026031176199 6.45533051729675 0, 3.46747932790801 6.457009677334758 0, 3.4669498386330364 6.458610906432366 0, 3.46767457907522 6.461656655114363 0, 3.4686873539393 6.463531565247443 0, 3.469307141996355 6.464961518774142 0, 3.4759185847219056 6.487302156484713 0, 3.499279179003224 6.497584352778277 0, 3.5194671504937913 6.505582945169733 0, 3.555977264714066 6.512318162809499 0, 3.59975152043511 6.522302700859115 0, 3.615237079363986 6.512190772414368 0)	t	[10, 6, 2, 200]	In the morning, when the boat is coming from Badore to Liverpool, they don't pick up people at the stops, they only drop off people\n\nIn the evening, when the boat is going to Badore from Liverpool, they only pick people up at those stops and the cost listed for those stop fields are from the location to destination rather than intermediate . This is the evening route as the morning route is differentsstops	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	10	200	f	f
64	2026-02-18 15:44:51.344	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	35	400	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3591741891575486 6.439064357935185 0, 3.363295408042652 6.432960952557403 0, 3.353693965264206 6.426457420245349 0, 3.3493181804324705 6.422165642999366 0, 3.3491200504610363 6.423413222263939 0, 3.347764109790347 6.426358133440893 0)	t	[10, 64, 78, 84]	\N	Fisayo 	fisayo@publictech.studio	10	84	f	f
38	2026-02-10 12:23:52.647	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	10	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.5890471 6.5632172 0, 3.6054649 6.5151518 0)	f	[69, 8]	\N	Mr Michael Diyepiriwei	diyemichael@gmail.com	69	8	f	f
31	2026-02-09 14:46:22.095	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	120	10000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.2366882862075954 6.437032706359787 0, 3.237013139521764 6.436659686731147 0, 3.2367604758327673 6.435906473184218 0, 3.2355188142795157 6.435827565034586 0, 3.2231960052289708 6.435008258699341 0, 3.2202350943124003 6.435786131806296 0, 3.2119264807787644 6.434787933210316 0, 3.2049925419524357 6.434049058566856 0, 3.1954311562160456 6.436926785837613 0, 3.1906752210310856 6.434947718655792 0, 3.1877237020120077 6.43396918433745 0, 3.1857625422948956 6.4343811799226245 0, 3.172814379152584 6.440922491787404 0, 3.1718879909015527 6.441059699815696 0, 3.168497193776517 6.440722921980239 0, 3.1666972698841107 6.43937089308001 0, 3.1648382086676676 6.436824625190535 0, 3.161836453275967 6.429187503424707 0, 3.1600978989181385 6.426932673646462 0, 3.1586113207117954 6.4259456158371435 0, 3.1565925521847973 6.424909478383157 0, 3.1533249745152006 6.423564014223388 0, 3.1498148610949954 6.420643801466525 0, 3.1475422416041 6.420098612322228 0, 3.1450922922475684 6.4208403321568 0, 3.1407618250371208 6.424687866591572 0, 3.134529883675164 6.427602395471645 0, 3.129958457773469 6.427057841494346 0, 3.1215463691570733 6.426202276930269 0, 3.1173592548107365 6.426445591289685 0, 3.1134385424061293 6.427193955588322 0, 3.11247066413182 6.4271092045492395 0, 3.1108654872016217 6.426056602193725 0, 3.1095816758923434 6.424795722881342 0, 3.108430360115875 6.420125314249134 0, 3.1071958360029726 6.4099434577192795 0, 3.1017012428889785 6.406541926021504 0, 3.0940712349018042 6.405899897386547 0, 3.0879373911034804 6.408024456020577 0, 3.0803848621850136 6.409428723210496 0, 3.067382292065332 6.409157429009731 0, 3.0553030692394145 6.411235006526496 0, 3.0514181097843505 6.41436413729285 0, 3.04715562186459 6.413171078238083 0, 3.0367520394909775 6.408138332027285 0, 3.033458840511173 6.407688324838816 0, 3.0239755648669018 6.4048227127176744 0, 3.0174651456543273 6.406118978207598 0, 3.0107257351382657 6.410894259306353 0, 3.007650860630008 6.411072125168388 0, 2.9856695834037055 6.405470693744675 0, 2.9655299163031827 6.408508470288993 0, 2.956804842891785 6.4079569444932645 0, 2.952088522144134 6.407195735225407 0, 2.9444484882434594 6.4028389806283315 0, 2.939102057758177 6.402122746019401 0, 2.927908612903771 6.406154887666581 0, 2.921619115583468 6.407437959156809 0, 2.899082387079744 6.406047300447803 0, 2.886241764882726 6.406999993296523 0, 2.8837333802198373 6.407635753692297 0, 2.877330767381494 6.4126754474357455 0, 2.853766457099823 6.423728682512854 0, 2.82979728795101 6.439214375655684 0, 2.8181839980296104 6.449805710705228 0, 2.8082646348645994 6.453752160714842 0, 2.8017794380355383 6.45489247936348 0, 2.7973627155243435 6.454240534916114 0, 2.7946337956620653 6.45313640536623 0, 2.789672080548087 6.451039537485315 0, 2.7834625052832394 6.447231703428869 0, 2.7499947244342877 6.442231262864453 0, 2.741883110826464 6.444896655896192 0, 2.737241965915075 6.449392556218395 0, 2.727767185694944 6.455418453924203 0, 2.720738670560678 6.455146886523394 0, 2.717846716450481 6.454705989543719 0, 2.7128513646557053 6.451848500099782 0, 2.710784442127874 6.450507217702025 0, 2.707951256864135 6.448790031018845 0, 2.706833480025807 6.447199637576162 0, 2.706590685374948 6.446902057934679 0, 2.7065624188267066 6.446770144319249 0, 2.7066075285560345 6.44659510783716 0, 2.7066718051391945 6.446423534176169 0, 2.7068056736123083 6.445980017715854 0, 2.706980451691635 6.44511667669255 0, 2.7071356508463253 6.444996737571515 0, 2.7074420023072605 6.44491126989962 0, 2.7079612373287887 6.4447103596807835 0, 2.707477970726316 6.444807736152157 0, 2.7072623969492398 6.444836317785175 0, 2.7069111907947736 6.4449304717613245 0, 2.706791602787007 6.445035585469597 0, 2.706600978755745 6.4463457628936 0, 2.7057937731751736 6.447923309026791 0, 2.7053895989484236 6.448045575381251 0, 2.7031113029712124 6.446995303254283 0, 2.691101335658608 6.443521821288755 0, 2.6724553846552936 6.440990640306751 0, 2.663273550831292 6.443938334717046 0, 2.6448414901198873 6.456218156714357 0, 2.628462522406565 6.4615666821603455 0, 2.627454906162825 6.4619795658877734 0, 2.62338128823194 6.465995687572757 0)	t	[18, 139, 4]	The stop name is Pashin	Mr Olayinka	olayinkamubo26@gmail.com	18	4	f	f
160	2026-03-04 00:38:42.648	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	Yes	\N	25	2300	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4419826471853696 6.436702621424786 0, 3.4436569059225226 6.4371090837078215 0, 3.4492536099520086 6.43796280925258 0, 3.4522703341062027 6.440228564667934 0, 3.4521199294183154 6.442323956674628 0, 3.4520112337417794 6.445765613932169 0, 3.4519879085322343 6.449272062603984 0, 3.453587510494592 6.450597684973677 0, 3.455837331575604 6.450925846197765 0, 3.4604787895335947 6.449068768139621 0, 3.464064995205022 6.448741518276073 0, 3.4681226759019568 6.449590361466378 0, 3.468524646528843 6.450742692209557 0, 3.467910255587074 6.454408702017936 0, 3.4666916968281014 6.458849855190632 0, 3.466993846882545 6.465801262981345 0, 3.467689021344061 6.495409709522848 0, 3.5010197 6.5393273 0)	f	[7, 14]	\N	Israel Ekundayo	israelekundayo@gmail.com	7	14	f	f
49	2026-02-11 13:32:23.942	LagFerry/Government: Operated by the government	Cowry card, Cash	Covered	No	Yes	50	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.2055781 6.453045 0, 3.2055503302167665 6.452859406910235 0, 3.2085599588723426 6.4488477620229645 0, 3.214914351434288 6.441771013024649 0, 3.2183566989445467 6.438241088231592 0, 3.2195216493488203 6.436670404135796 0, 3.234999185863245 6.430447548195033 0, 3.2438312022125615 6.426307013354048 0, 3.2590812364505837 6.426404669666653 0, 3.280714036242955 6.428652344339639 0, 3.2913610283814023 6.430686729604574 0, 3.2973840808382704 6.43665738404745 0, 3.3050338469901703 6.437912934627278 0, 3.3114494968423003 6.4354963873772135 0, 3.31791719609825 6.432080226223633 0, 3.320369787434771 6.431339452040831 0, 3.329808869330492 6.435761473222598 0, 3.3359172043088847 6.437662539885238 0, 3.33939850971376 6.437550906958947 0, 3.343574899360192 6.436438754191585 0, 3.3462507467164073 6.435937632109329 0, 3.3478441839150435 6.4358585051234485 0, 3.351206863309187 6.4371395894709025 0, 3.3554565723224528 6.43877206935116 0, 3.359172844741863 6.439064160007163 0, 3.3655859540163817 6.431222724284254 0, 3.3680240441413503 6.429962674273867 0, 3.3787626168140434 6.434235720152785 0, 3.380996244598805 6.434907570793428 0, 3.383067385642164 6.434684601322047 0, 3.392446385790919 6.431804239191692 0, 3.3946036835186533 6.43125700997129 0, 3.39742618013031 6.432816023428927 0, 3.3987593326409353 6.4387120670337765 0, 3.389713112398539 6.4492081354225945 0)	t	[9, 10, 6]	\N	Mr Pascal	N/A	9	6	f	f
1	2026-01-13 00:00:00	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	\N	\N	180	12000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	Outside Lagos	t	[1, 13, 4]	\N	Odusami Sheriff Oluwafemi	odusamioluwafemi@gmail.com	1	4	f	f
16	2026-02-09 10:35:32.581	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	15	400	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.359173807347691 6.4390637347789 0, 3.361488574218879 6.436946750568449 0, 3.3632942421516896 6.4345666418436185 0, 3.36522052771621 6.433376586765089 0, 3.3684111828024026 6.4328413828788005 0, 3.3698058335616654 6.433550905544749 0, 3.370295825087261 6.434538550266627 0, 3.373043133226452 6.433601578458385 0, 3.3753376188192217 6.433031169011391 0, 3.376979975700015 6.432784770773643 0)	t	[10, 27, 121]	This route is mostly for the fish market. Frequency on market days(Tuesdays, Fridays and Saturdays) are higher	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	10	121	f	f
166	2026-03-06 15:05:12.926	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	Yes	\N	35	800	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.362453877 6.418094084 0, 3.358957304304056 6.417867445809533 0, 3.354177506749585 6.41838310861624 0, 3.352571018774845 6.418006278103647 0, 3.350520788694608 6.41781885536157 0, 3.34949687511948 6.4191566028263 0, 3.348782880464041 6.420584592137179 0, 3.348683714539674 6.421536585011099 0, 3.349367926556892 6.42221793457128 0, 3.35212872799195 6.42422027407363 0, 3.35554483070657 6.42642412400888 0, 3.35578270020135 6.426971742322559 0, 3.3577350772919665 6.427928138699581 0, 3.359255169204363 6.427660217332676 0, 3.3642176259488137 6.432754563492885 0, 3.3592365 6.4390793 0)	t	[129, 24, 90, 78, 64, 85, 10]	\N	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	129	10	f	f
14	2026-02-09 08:47:47.182	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	Yes	8	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3700913 6.4346659 0, 3.376968865 6.43277977 0)	f	[27, 121]	Boats are also called Wooden boats. They still get water hyacinths but they push it away to make way. This is mostly used by workers 	Mr Ibrahim Owolabi	owolabiibrahim580@gmail.com	27	121	f	t
158	2026-03-03 09:48:16.751	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat, Wooden boats	Yes	\N	30	500	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (2.8609131768460827 6.4455972331257385 0, 2.8591187527476905 6.445847108846607 0, 2.858786314629498 6.446177445319179 0, 2.858222615211389 6.4469889231294815 0, 2.8624120685024934 6.470817234815939 0, 2.8624138175231053 6.471323990118748 0, 2.862173996845769 6.471750700003241 0, 2.862023411768888 6.472321493181269 0)	f	[88, 157]	During the water hyacinth season, they move to another waterside to board- it’s also Iya Afin. Peak period is only during the festive period 	Mr Kadeem Fayemi	Kazeemfayemi0@gmail.com	88	157	f	f
75	2026-02-20 12:15:51.263	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Catamaran, Covered, Banana	Yes	\N	40	2500	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.3749219 6.4477052 0, 3.378431146034248 6.4569343602412825 0, 3.37916756677424 6.462345748607691 0, 3.381397091294863 6.462725988442628 0, 3.382478301866796 6.462734506635153 0, 3.3921029720063465 6.476506600908474 0, 3.4020154302070407 6.490659963728727 0, 3.4084683094008854 6.499307718415354 0, 3.4161789863385765 6.509164445300138 0, 3.4309555872458875 6.528023749728938 0, 3.435419391044161 6.534512963056458 0, 3.441817453745455 6.543858022310042 0, 3.4529479673154357 6.55993250286694 0, 3.458378900565937 6.567585389412294 0, 3.463594916160415 6.574704507557957 0, 3.4749940768003977 6.589636641981524 0, 3.4862304 6.601832 0)	t	[5, 1, 3]	 N/A	Sikigha Charity	isikighacharity@gmail.com	5	3	f	f
77	2026-02-20 12:31:01.47	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Catamaran, Covered, Banana	Yes	\N	30	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.294149195 6.474484688 0, 3.297866837009792 6.468932609854349 0, 3.300762619991218 6.46398727686595 0, 3.3077366 6.4590664 0)	f	[36, 101]	 N/A	Sikigha Charity	isikighacharity@gmail.com	36	101	f	f
176	2026-03-30 15:25:49.754041	LagFerry/Government: Operated by the government	Cowry card	Catamaran	\N	\N	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.389713112398539 6.4492081354225945 0, 3.397423474802679 6.438498577817327 0, 3.3962892062729964 6.433296267775617 0, 3.391981511678779 6.433146945582109 0, 3.3812416825550997 6.43616697250242 0, 3.370296642664556 6.434538305719656 0, 3.369909472988809 6.43479612309973 0, 3.3702692529812737 6.433809473542169 0, 3.3701230430639555 6.4331868056602275 0, 3.3684362298341455 6.432738683287582 0, 3.3643971564240474 6.432884046619179 0, 3.3591733817758893 6.439064030138624 0, 3.357112082254332 6.439262355457544 0, 3.3560602335198837 6.439288485779798 0, 3.352705318527427 6.438056990952774 0, 3.349749756258916 6.436646551574441 0, 3.3457040389264137 6.435438535839381 0, 3.343806330972484 6.435863591878601 0, 3.3433950241762034 6.435329991824105 0, 3.343224618696155 6.435865379827078 0, 3.3402558254274197 6.436773896118794 0, 3.3389256693545235 6.437104464036324 0, 3.337152026615172 6.43722527786997 0, 3.3345379492362213 6.437005090330359 0, 3.3330321824109888 6.436589994779396 0, 3.3241663539735953 6.4318174686325875 0, 3.3222487599819033 6.431099232006687 0, 3.3201541573145334 6.430688810622087 0, 3.3172669655520792 6.431151480397148 0, 3.312423671715976 6.434143895917174 0, 3.309119631167988 6.436055250286358 0, 3.305633730471982 6.436825028872747 0, 3.3002111591797245 6.436680717199366 0, 3.2990007528723027 6.43629583398392 0, 3.2921745527713426 6.429464262909491 0, 3.2879986400694747 6.429413771011497 0, 3.2854860247902025 6.429096503063775 0, 3.2805397761004826 6.427685056188494 0, 3.277054000606313 6.427357116324572 0, 3.271111828430719 6.427539891281199 0, 3.2673358322713 6.427390884500653 0, 3.2635189408464953 6.426632303851903 0, 3.2553696866160635 6.425054768698175 0, 3.253260101048056 6.425683980526827 0, 3.242040379312243 6.42773125377586 0, 3.2214635336343065 6.436742968927732 0, 3.218869582065281 6.438419386476113 0, 3.2167539038314885 6.440593224347751 0, 3.214969250083186 6.442609736679884 0, 3.2074427804055006 6.450961069602684 0, 3.205773183637973 6.452774857044332 0, 3.2055781 6.453045 0)	t	[6, 27, 10, 55, 59, 9]	future omi eko	Fisayo 	fisayo@publictech.studio	6	9	f	t
171	2026-03-30 15:10:34.953859	LagFerry/Government: Operated by the government	Cowry card	Catamaran	\N	\N	9999	1	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4862304 6.601832 0, 3.4536609309143103 6.546801048532899 0, 3.4643444895650646 6.46117059807689 0, 3.4667549447163992 6.448933884778654 0, 3.464137180540831 6.448269830901538 0, 3.4617817418618415 6.448216025442321 0, 3.4560285152039114 6.450072310496438 0, 3.453347895321599 6.449485123024033 0, 3.4535807050599203 6.443063568237605 0, 3.453417440672041 6.441137260570841 0, 3.452676494863482 6.439983047015957 0, 3.4494329446069116 6.43754593338997 0, 3.4437167600645466 6.436918319180791 0, 3.4419822683274788 6.436702694961895 0, 3.440145650103247 6.438618821371541 0, 3.4358748161680595 6.441472331827942 0, 3.435663125040918 6.44154567764771 0, 3.4296620679659497 6.441657372221357 0, 3.427179994 6.442095174 0)	t	[3, 96, 7, 2]	future omi eko	Fisayo 	fisayo@publictech.studio	3	2	f	t
41	2026-02-10 13:02:56.74	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Speed boats	Yes	\N	7	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.5790217 6.4906336 0, 3.56216718694834 6.522970642064163 0, 3.553069 6.536139 0)	f	[109, 31]	\N	Mr Ismail Olowoidiaba	ismailolalekan68@yahoo.com	109	31	f	t
50	2026-02-12 08:11:04.563	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	Yes	\N	2	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.4076028852038247 6.582567357189847 0, 3.4082012334543985 6.582420173741085 0)	f	[23, 20]	Agboyi 1 should be renamed to Agboyi 3	Otudero Oluwayemisi	None	23	20	f	f
110	2026-02-27 08:40:20.896	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	Yes	\N	150	12000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	\N	t	[101, 146, 4]	Apparently, Owode and Pashi are regarded as the same place because of proximity.	Israel Ekundayo	israelekundayo@gmail.com	101	4	f	f
174	2026-03-30 15:20:18.799191	LagFerry/Government: Operated by the government	Cowry card	Catamaran	\N	\N	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3825329213594273 6.462767750725462 0, 3.379709709565617 6.461718393242336 0, 3.3795961817199327 6.4569667339603285 0, 3.3807319031366205 6.453615441751367 0, 3.389712919245568 6.449206760040838 0)	f	[1, 6]	future omi eko	Fisayo 	fisayo@publictech.studio	1	6	f	t
175	2026-03-30 15:22:44.441778	LagFerry/Government: Operated by the government	Cowry card	Catamaran	\N	\N	9999	1	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4068744 6.5482938 0, 3.4084175044855556 6.547351296052128 0, 3.409019234146399 6.530597379832628 0, 3.399905528234399 6.528355070748717 0, 3.4076548708629417 6.5124118027403455 0, 3.398269318763738 6.486190882759416 0, 3.386543924942302 6.469224024421017 0, 3.382533438705593 6.462767986870944 0, 3.3814385562310605 6.462820002085024 0, 3.3790652965622314 6.462520670564089 0, 3.378061493687511 6.457065904335678 0, 3.3749827372821244 6.447536280448162 0, 3.3785052541190908 6.448601448045821 0, 3.3854991750372108 6.4492281047334075 0, 3.389712736645123 6.449207769577413 0, 3.402228278932 6.438776476445426 0, 3.402898151243221 6.43893169787971 0, 3.4036358886018263 6.440034147455037 0, 3.404883645003423 6.44126449169255 0, 3.405751405550518 6.441527401176572 0, 3.407902387996657 6.441350946017437 0, 3.4104234567243417 6.44061323479313 0, 3.412945827826933 6.438126790586162 0, 3.417770922911754 6.4374645344195125 0, 3.422658215370582 6.438903652965244 0, 3.427179994 6.442095174 0)	t	[118, 32, 1, 5, 6, 2]	future omi eko	Fisayo 	fisayo@publictech.studio	118	2	f	t
111	2026-02-27 09:42:15.519	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	Yes	\N	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.204245472039803 6.453176016321364 0, 3.204691272048581 6.451306611466339 0, 3.206286535856859 6.447691481869566 0, 3.207021241535907 6.446734703680288 0, 3.207058983368812 6.446451639933496 0, 3.207073136556152 6.446220471206949 0, 3.20701180607768 6.446017608855081 0, 3.206874991933397 6.445489223194404 0, 3.206851403287831 6.445215594905838 0, 3.206804225996699 6.444706080161613 0, 3.206754564188978 6.444432747288471 0, 3.206611361490344 6.444041559428788 0, 3.206527535520412 6.443884385735166 0, 3.206503086279182 6.443779603272752 0, 3.206911246986321 6.443469776041071 0, 3.207035222189985 6.443091325419357 0, 3.207031959684626 6.442796068684314 0, 3.207031959684626 6.442169667655271 0, 3.207009122147109 6.442053848715006 0, 3.206969564269626 6.441954138394951 0, 3.206950397050636 6.441885829688987 0, 3.206819560367967 6.441900522322349 0, 3.206682097859101 6.44193717899138 0, 3.206556854239912 6.442025765941538 0, 3.206275819777342 6.442205994564274 0, 3.206031441983802 6.44230374568169 0, 3.205793173635101 6.442395387354266 0, 3.205686258350428 6.442386223187009 0, 3.205310527492861 6.442374004297332 0, 3.205050876087226 6.442248760678145 0, 3.204772896347075 6.442053258443313 0, 3.204284140759996 6.441714184254777 0, 3.203948121293879 6.441414821457691 0, 3.203789150136757 6.441369527365509 0, 3.203600712149039 6.441268060756738 0, 3.203392676480475 6.441178615486484 0, 3.203386699517871 6.441130799785653 0, 3.203358807025721 6.440997314287503 0, 3.203332906854437 6.440841913259805 0, 3.203299037399683 6.440680535269504 0, 3.203251221698853 6.440503218712259 0, 3.203231298490174 6.440395633385391 0, 3.203245244736249 6.440290040379391 0, 3.203238129548885 6.440241033406033 0, 3.203245732158587 6.440090881864421 0, 3.203253334768289 6.440049067511061 0, 3.203237227199949 6.440017658768764 0, 3.203113913993497 6.439907346520113 0, 3.203059773057337 6.439859522026505 0, 3.202975839514171 6.439782976171497 0, 3.202875950657815 6.439673585476046 0, 3.202806617388411 6.43958688975491 0, 3.202761060677791 6.439535973431276 0, 3.202744981838749 6.439503815753192 0, 3.202661907837032 6.439444860010037 0, 3.202503799253118 6.439329628330236 0, 3.202198301311318 6.439096485164126 0, 3.202039905356677 6.438649159270327 0, 3.202036314949733 6.438634797642549 0, 3.202044064682965 6.438582941520941 0, 3.202058903121032 6.438353316713476 0, 3.202069670598982 6.438179991338727 0, 3.202024113888362 6.437928089527067 0, 3.202000121152798 6.437775849379801 0, 3.201913346068144 6.437750730276349 0, 3.200908287509451 6.437481633442951 0, 3.199729685962439 6.437172448732188 0, 3.199509817228341 6.436724445702199 0, 3.199493808525991 6.436292210738742 0, 3.199541834633042 6.435795940965884 0, 3.199637886847143 6.435235636383625 0, 3.199862008680047 6.434339149052009 0, 3.199893132458986 6.43346280646663 0, 3.199323491248226 6.432551380529413 0, 3.199295009187688 6.431241205744664 0, 3.199437419490378 6.428791748538393 0, 3.19955134773253 6.427111306966649 0, 3.19926652712715 6.425146044789524 0, 3.198867778279618 6.421842125767112 0, 3.199291203265197 6.419551370070374 0, 3.198753850037465 6.4185382067447 0, 3.199181080945536 6.417313478141565 0, 3.199608311853606 6.41637357014381 0, 3.202484999967948 6.41594633923574 0, 3.205304723961213 6.415433662146055 0, 3.210824404637061 6.415927806687773 0, 3.211848608537532 6.415280941066423 0, 3.212657190564219 6.414526264508182 0, 3.205541668729372 6.406683018849317 0)	t	[107, 89, 77]	\N	Israel Ekundayo	israelekundayo@gmail.com	107	77	f	f
112	2026-02-27 09:51:54.484	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	Yes	\N	30	2000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.204245483565353 6.453176023250619 0, 3.204254438520946 6.453167315513737 0, 3.205189708964279 6.45212890705691 0, 3.20600831992426 6.451110477673626 0, 3.212150880467128 6.444027833691879 0, 3.2196807000499117 6.436800085043404 0, 3.2279077782567 6.433341994044476 0, 3.2391552166842335 6.428149792562023 0, 3.242830018360153 6.426293855282433 0, 3.24376192989665 6.422836136097881 0, 3.243496349985531 6.417382039815242 0, 3.25130128973135 6.411338005772572 0, 3.261600491251755 6.407580321328695 0)	f	[107, 60]	\N	Israel Ekundayo	israelekundayo@gmail.com	107	60	f	f
113	2026-02-27 09:55:26.927	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat, Wooden boats	Yes	\N	25	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.204245481 6.453176022 0, 3.205776272723006 6.451213609763073 0, 3.212697757950497 6.442439488371421 0, 3.212715862091557 6.441483166547236 0, 3.21263238854742 6.441552727834017 0, 3.212373620560597 6.441800366014954 0, 3.212039726384052 6.441936706137044 0, 3.211878344198722 6.441945053491457 0, 3.21157505698836 6.44192835878263 0, 3.211516625507465 6.441886622010562 0, 3.211268987326527 6.441694632859049 0, 3.211082563077956 6.441602811960498 0, 3.210851619605845 6.441647331184038 0, 3.210698584774929 6.441594464606085 0, 3.21067910761463 6.44146925428988 0, 3.210648500648447 6.441316219458963 0, 3.210612328779321 6.441129795210393 0, 3.210373037952797 6.441115882953037 0, 3.210222785573352 6.441191009142759 0, 3.209908368557105 6.441338479070733 0, 3.209593951540858 6.441352391328089 0, 3.20909311027604 6.441591682154614 0, 3.20858670410828 6.441502643707535 0, 3.207913350852247 6.441708545116405 0, 3.207284516819753 6.441786453757598 0, 3.206686134116508 6.441905404721144 0, 3.206646984052194 6.441924979753302 0, 3.206262008419761 6.442189242687428 0, 3.206229383366165 6.442202292708867 0, 3.205795470153339 6.442365417976847 0, 3.205328931886917 6.442349105450049 0, 3.205080981479588 6.442238180267823 0, 3.204816718545461 6.442062004978404 0, 3.204307767709364 6.441716179410287 0, 3.203967593928279 6.441399374070119 0, 3.203788335041375 6.441349388418964 0, 3.203641160332373 6.441274710980389 0, 3.203405503344249 6.44116843429947 0, 3.203350837742249 6.440823982371993 0, 3.203249229377985 6.440407587310599 0, 3.20326317562406 6.440286055737656 0, 3.203259190982324 6.440242224678562 0, 3.203277121870136 6.440044984912637 0, 3.203267160265796 6.440031038666562 0, 3.203241145193472 6.439994874366905 0, 3.202972245210545 6.439760263643545 0, 3.202767412002075 6.439521141175508 0, 3.202754779116971 6.439497680103172 0, 3.202205600118752 6.439091138688628 0, 3.202118645270287 6.43883740158983 0, 3.202050221782971 6.438640208900688 0, 3.202049271456758 6.438631655964774 0, 3.202049271456758 6.438627379496817 0, 3.202050221782971 6.438619776887115 0, 3.202082990240014 6.438193177588351 0, 3.202018362915009 6.437769509568876 0, 3.20200878849649 6.437758738348042 0, 3.200752373851886 6.437410283125082 0, 3.199771967632287 6.437151307897263 0, 3.199655693040205 6.436900260482541 0, 3.19957112970051 6.436696779946398 0, 3.199563201887413 6.436461588157869 0, 3.199649632619111 6.436072537363941 0, 3.1999317036962562 6.435071134597871 0, 3.200236755101518 6.433828543093221 0, 3.2003070190311345 6.432947858922435 0, 3.1997381846599064 6.432159589725955 0, 3.199684248283623 6.431567291018999 0, 3.199979714262889 6.42706373911336 0, 3.1996543041362475 6.42495785784266 0, 3.1994467241888467 6.422950812640763 0, 3.1993674025848375 6.421075395681876 0, 3.199313162298789 6.419549122371283 0, 3.1991658082454473 6.419394438591079 0, 3.1991616114517223 6.418975395484804 0, 3.1998529839453553 6.417568222034982 0, 3.2016135999796616 6.416626814828135 0, 3.2049941792152783 6.416292701932701 0, 3.2089233226028524 6.417041137533617 0, 3.211665041442214 6.416269207876866 0, 3.215067080017983 6.413684301740902 0, 3.220710249046361 6.409566035152125 0, 3.223126060666493 6.408135629318128 0, 3.225238583047931 6.40835632435245 0, 3.230747874272814 6.412269804000883 0, 3.236747347 6.417336462 0)	f	[107, 74]	\N	Israel Ekundayo	israelekundayo@gmail.com	107	74	f	f
115	2026-02-27 10:15:22.948	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat	Yes	\N	15	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.204245483565353 6.453176023250619 0, 3.205144588675147 6.451046020117722 0, 3.206507009062568 6.447753733168739 0, 3.206549468624587 6.44759333037889 0, 3.206606081373945 6.4474895403384 0, 3.206757048705567 6.447263089340966 0, 3.207063701097925 6.446852646908118 0, 3.207120313847283 6.446753574596741 0, 3.207162773409302 6.446512970411968 0, 3.207077854285265 6.445913818814591 0, 3.206922169224529 6.445319384946329 0, 3.206880303143875 6.444715659936991 0, 3.206716143952759 6.444024095685053 0, 3.206611361490344 6.44379357426774 0, 3.206992071103785 6.443496690624233 0, 3.207093360817452 6.443206792478219 0, 3.207110824561188 6.442976271060906 0, 3.207093360817452 6.442218344582773 0, 3.207087422275739 6.441972286081016 0, 3.207058059727502 6.441838523361273 0, 3.206675938787262 6.441918250835998 0, 3.206243656827114 6.442209225532754 0, 3.206215925531559 6.442215138823721 0, 3.205791799834811 6.442375001586341 0, 3.20531873655767 6.442355426554183 0, 3.205077311161059 6.442244501371957 0, 3.20493034267917 6.442150338416655 0, 3.204285751505772 6.441704438429321 0, 3.203959990375129 6.441401780924966 0, 3.203785557996665 6.441354418491078 0, 3.203564692343531 6.441242737999472 0, 3.203400667163599 6.441170960117492 0, 3.203338883817041 6.440800074521579 0, 3.203299037399683 6.440642681173014 0, 3.203243252415381 6.440407587310599 0, 3.203245244736249 6.440385671781051 0, 3.203257198661456 6.440301994304598 0, 3.203249229377985 6.440246209320297 0, 3.203251221698853 6.440220309149014 0, 3.203267160265796 6.440041000270901 0, 3.203241930853736 6.440001551200425 0, 3.202966336252044 6.439760168342391 0, 3.202766767747371 6.439528288746485 0, 3.202753876768035 6.439502191847852 0, 3.202203687836461 6.439092172085316 0, 3.202045470151907 6.438640208900688 0, 3.202045470151907 6.438633081454093 0, 3.202045945315013 6.438625478844391 0, 3.202047845967439 6.438616925908477 0, 3.202071022216864 6.438311661017526 0, 3.202078203030754 6.438183603169832 0, 3.202035118147418 6.437937061892962 0, 3.202027937333528 6.437876024974902 0, 3.20200878849649 6.437765919161931 0, 3.20082636677412 6.437441994377468 0, 3.199756112006094 6.43715923571036 0, 3.199639837414012 6.436902903086906 0, 3.199552631469951 6.436702065155129 0, 3.199544703656855 6.436387595235635 0, 3.199584342722337 6.435927782076038 0, 3.199663620853302 6.435639738200199 0, 3.200208828370111 6.433215960589242 0, 3.19998061654438 6.432742650786587 0, 3.199639019934555 6.432214728753221 0, 3.199639019934555 6.430444637229582 0, 3.199794291120839 6.429171413502052 0, 3.199918508069866 6.427028671131331 0, 3.199483748748271 6.424668549099812 0, 3.199234728921212 6.421911313685259 0, 3.199046059781652 6.418784796515402 0, 3.199827689074116 6.417059821525136 0, 3.200339791024351 6.416089523093111 0, 3.201283136722153 6.415119224661087 0, 3.201965091665905 6.413293298811107 0, 3.20093302973272 6.410624343878806 0, 3.1978444058329867 6.407965832784628 0, 3.194183016827545 6.407439525702606 0, 3.19115144488051 6.408455790262489 0, 3.182888678124085 6.415290468459889 0, 3.181364634756622 6.415898823714224 0, 3.1785234007256182 6.414920753476858 0, 3.177063591210343 6.414218876271115 0, 3.170269042620859 6.40538835795013 0, 3.164837180309284 6.403912901071839 0)	f	[107, 19]	\N	Israel Ekundayo	israelekundayo@gmail.com	107	19	f	f
125	2026-02-27 12:21:42.564	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	\N	19	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.389712483830607 6.449208123966997 0, 3.4010509386485523 6.433772871148591 0, 3.398339944598618 6.426261879500061 0, 3.3989295877063057 6.4178816859334376 0, 3.3989188190075765 6.403028966072085 0, 3.3985258428995735 6.399357664288097 0, 3.3982693814747336 6.398639388657671 0, 3.397932413143593 6.3983737849970055 0, 3.3974331781763567 6.3984670778874175 0, 3.3970315605724295 6.398989076688025 0, 3.396618723749384 6.401007351498663 0)	t	[6, 106, 130]	the frequency of passengers cannot be streamlined as much as possible cause different days and demand varies. peak hours are early afternoons till eaely evenings.	Sikigha Charity	isikighacharity@gmail.com	6	130	f	f
180	2026-04-07 16:18:53.901533	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	Yes	\N	5	300	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.1438990035366317 6.4493813109168485 0, 3.1415487753784532 6.447362818041896 0)	f	[51, 41]	\N	Fisayo 	fisayo@publictech.studio	51	41	f	f
138	2026-02-27 15:35:41.799	Informal Commercial: Operated by unlicensed operators (NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	Yes	\N	5	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.351582550566885 6.45040017450207 0, 3.351166978676504 6.450387387674674 0)	f	[35, 16]	They are open on public holidays. Passengers are given a 15-minute grace period before they close at 10:00 p.m. By 11:00 p.m., which is far later than the official closure hour, you could also be able to take a boat to the other side. No life jackets are being worn by the passengers. Passengers are standing in these boats. Their parent organization is the Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON). Although they open at 5:00 am, you can catch boats about here around 4:30 am.	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	35	16	f	f
170	2026-03-24 12:09:58.961343	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer, Debit card/POS	Catamaran	\N	Yes	30	15000	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.424595555 6.43922746 0, 3.4241402329127197 6.439759245888567 0, 3.4226416406281714 6.438719123448962 0, 3.419035321512098 6.437326802869208 0, 3.416133490164583 6.43728133806227 0, 3.4128761827153937 6.438048313113427 0, 3.410414445080022 6.440536053387802 0, 3.4078888788606037 6.44128749811496 0, 3.405760910388693 6.441474200271841 0, 3.4049151032673706 6.441212273188455 0, 3.403704144359324 6.439955614909522 0, 3.403458480088773 6.438816535772091 0, 3.4015299173765072 6.4273334505166275 0, 3.399226110329664 6.3997113254552715 0, 3.3990718316701134 6.398104828087796 0, 3.3976038529129795 6.397303586321563 0, 3.3960782280121293 6.398650612346827 0, 3.3965995 6.4010654 0)	f	[54, 130]	Ticket prices are round-trip.	Hannah Kates	hannah@publictech.studio	54	130	f	f
168	2026-03-06 21:23:05.205	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Fibre boat, Wooden boats	Yes	\N	20	1500	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.152975976991251 6.424469742978864 0, 3.1530220247297267 6.424451966525188 0, 3.154339648614596 6.4247921148404465 0, 3.155778200402815 6.425072531453566 0, 3.1597425032358455 6.427378816790322 0, 3.1616964260238416 6.429554487314493 0, 3.163376410336806 6.434323925991501 0, 3.164501692376765 6.437949834786924 0, 3.1662403891790896 6.439847249297308 0, 3.1687691798082023 6.441301715347479 0, 3.172741640428719 6.441385456571112 0, 3.174754262074168 6.440575492880162 0, 3.178421185353133 6.4386529605975085 0, 3.180380672273963 6.438700022813563 0, 3.182297819453152 6.438713613176365 0, 3.182901231561536 6.438646567386544 0, 3.183772826829201 6.438110201067981 0, 3.184242147357944 6.438110201067981 0, 3.187929665798067 6.440657941081157 0, 3.187058070530402 6.440859078450618 0, 3.186253521052557 6.441395444769181 0, 3.184912605256148 6.442334085826667 0, 3.18357168945974 6.443473864253614 0, 3.183102368930997 6.44434545952128 0, 3.183236460510638 6.445150008999125 0, 3.184108055778303 6.446088650056611 0, 3.185583063154353 6.446692062164995 0, 3.187192162110043 6.446960245324276 0, 3.188868306855553 6.446625016375174 0, 3.19007513107232 6.446490924795533 0, 3.190477405811243 6.448971619018889 0, 3.192421733716035 6.44923980217817 0, 3.1941622858448095 6.449303515470205 0, 3.195237656888493 6.449306847967991 0, 3.195908114786697 6.448301161120685 0, 3.19644448110526 6.448032977961403 0, 3.197181984793285 6.448636390069787 0, 3.197919488481309 6.449038664808709 0, 3.198724037959154 6.448167069541044 0, 3.199260404277718 6.448703435859607 0, 3.2016986772691065 6.4510159675199095 0, 3.204245472039803 6.453176016321364 0)	f	[81, 107]	\N	Israel Ekundayo	israelekundayo@gmail.com	81	107	f	f
135	2026-02-27 15:24:57.243	Informal Commercial: Operated by unlicensed operators (NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	Yes	\N	5	50	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.351421830308873 6.448196836028655 0, 3.350890567695216 6.448418195451012 0)	f	[105, 147]	They work on public holidays. They close by 10:00 pm, but they give a grace of 15 minutes to passengers. No life jackets worn by passengers. Passengers stand in these boats. They are under The Association of Tourist Boat Operators and Water Transporters of Nigeria (ATBOWATON).	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	105	147	f	f
89	2026-02-25 09:32:40.256	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer, Debit card/POS	Covered	\N	\N	10	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.6152349 6.5121945 0, 3.5890471 6.5632172 0)	f	[200, 69]	This route is mostly for workers 	Mr Haruna deji 	Harunadeji05@gmail.com	200	69	f	f
155	2026-03-03 08:48:57.96	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	60	3000	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.600195878 6.56021613 0, 3.5675395919020985 6.536065959390483 0, 3.5366968042112807 6.520288374669558 0, 3.4736293018554854 6.4903140117301135 0, 3.388769442375831 6.467824057139126 0, 3.3824784268241403 6.462734251023601 0, 3.379515026606465 6.46190160775643 0, 3.379461217800876 6.456943156351156 0, 3.3806238083943745 6.453528671372961 0, 3.3829830242539716 6.451701144408234 0, 3.389713112398539 6.4492081354225945 0)	t	[42, 1, 6]	\N	Charity Sikigha	isikighacharity@gmail.com	42	6	f	f
179	2026-04-07 16:03:57.872462	Informal Commercial: Operated by unlicensed operators (NOT under the jurisdiction/licensed by LASWA/NIWA)	Cash	Wooden boats	Yes	\N	20	100	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.407602775396478 6.58256785349664 0, 3.4078998 6.5822202 0, 3.4077758 6.5818232 0, 3.4076862 6.5814012 0, 3.4077058 6.5812489 0, 3.4077522 6.5811072 0, 3.4077602 6.5810406 0, 3.4078701 6.58083 0, 3.4079573 6.5806436 0, 3.4081544 6.5803825 0, 3.4084039 6.5802865 0, 3.408318 6.5801853 0, 3.4083395 6.580056 0, 3.4083932 6.5799428 0, 3.4085461 6.579671 0, 3.4086802 6.5794845 0, 3.4088947 6.5791141 0, 3.4090825 6.5789223 0, 3.4091925 6.5789036 0, 3.4092274 6.5789436 0, 3.4092542 6.5789995 0, 3.409281 6.5790555 0, 3.4092944 6.5791248 0, 3.4093185 6.5791994 0, 3.4093427 6.57925 0, 3.409391 6.5793459 0, 3.4094634 6.5794285 0, 3.4094983 6.5794738 0, 3.4095586 6.5795657 0, 3.4095841 6.5796111 0, 3.4096109 6.5796537 0, 3.4096632 6.5796777 0, 3.4097329 6.5796936 0, 3.4097853 6.579719 0, 3.4098764 6.5797802 0, 3.4099462 6.5798229 0, 3.4100213 6.5798495 0, 3.4101018 6.5798895 0, 3.4101715 6.5798922 0, 3.410252 6.5798842 0, 3.4103271 6.5798815 0, 3.4104183 6.5798975 0, 3.4105282 6.5799002 0, 3.4106033 6.5799055 0, 3.4106677 6.5799161 0, 3.4107455 6.5798868 0, 3.4108125 6.5798309 0)	t	[23, 21, 112, 22]	\N	Fisayo 	fisayo@publictech.studio	23	22	f	f
154	2026-02-28 16:31:06.07	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats	Yes	Yes	10	1000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.389712483830607 6.449208123966997 0, 3.3981149241239166 6.438602925286801 0, 3.4013952654887305 6.434195277701036 0, 3.4012483838235177 6.431533922693276 0, 3.399752068931498 6.426949556511204 0, 3.3983410982028346 6.426259859919696 0)	f	[6, 106]	\N	Israel Ekundayo	israelekundayo@gmail.com	6	106	f	f
10	2026-01-13 00:00:00	LagFerry/Government: Operated by the government	Cowry card	Covered,Catamaran	\N	\N	40	2500	Yes, this route gets disrupted and doesn't work during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4862304 6.601832 0, 3.4726187083094504 6.58749197143752 0, 3.4476135020548617 6.55401865861223 0, 3.426197765416483 6.5237357731441055 0, 3.4067343122838443 6.498660972457295 0, 3.3920424339650843 6.478170749479121 0, 3.38620417542527 6.47005718219117 0, 3.379417665689802 6.463593839585963 0, 3.3756102405488226 6.460133596252768 0, 3.374568854999654 6.452098598684394 0, 3.396634499025992 6.4382351337867485 0, 3.3964534267976814 6.43744450474444 0, 3.3948567 6.4335377 0, 3.3872855 6.4354066 0, 3.382306362706959 6.436956355530353 0, 3.381315246516077 6.437126261163075 0, 3.380154224692472 6.437041308346714 0, 3.3777788 6.4362252 0, 3.371224355644744 6.432961653190958 0, 3.370033412056305 6.432586247059819 0, 3.369049589091944 6.432612137137829 0, 3.368285831790663 6.432612137137829 0, 3.36735378898232 6.432948708151953 0, 3.36599455988682 6.433272334127072 0, 3.364946011727434 6.4336218501802 0, 3.364285814738191 6.4338936959993 0, 3.36368387042447 6.434366189922974 0, 3.362654739823592 6.435589496108924 0, 3.362175773380415 6.436327363332196 0, 3.361981597795344 6.436560374034281 0, 3.3592365 6.4390793 0)	f	[3, 10]	\N	Odunsi Omosewa Ajayi	odunsiomosewa@gmail.com	3	10	f	f
136	2026-02-27 15:25:13.709	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	60	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.389712743553326 6.449208204922252 0, 3.3942581268569016 6.446050146992505 0, 3.3987175975131416 6.44249752057788 0, 3.401889597480791 6.439631156206873 0, 3.402163936395179 6.439517184709804 0, 3.4023700250430324 6.43956619114654 0, 3.4024701540541864 6.439690414994142 0, 3.4025702830653404 6.439814638841744 0, 3.402930364118834 6.4403115461938105 0, 3.4037304377365727 6.441201659355251 0, 3.4048950851861615 6.442051881829567 0, 3.4055317016095104 6.442291225253339 0, 3.406946227363831 6.442495224923931 0, 3.408779120312196 6.44234707427862 0, 3.411179341169589 6.4413304584378865 0, 3.4148595839706046 6.439459062471519 0, 3.4182381518224343 6.438663546910677 0, 3.4216431970981995 6.439796407179965 0, 3.4248318303276712 6.441035265795154 0, 3.427175929330542 6.442095819404855 0, 3.4303638012840194 6.4419228367215435 0, 3.4357137863173786 6.442009341133054 0, 3.437155764343044 6.44140278483402 0, 3.4398362780404264 6.440149510298384 0, 3.443231555584459 6.437915388074416 0, 3.445218159043621 6.437778888335049 0, 3.448859884754193 6.438740995632407 0, 3.451626442432888 6.440461064426022 0, 3.4522227405141184 6.440944070228081 0, 3.45266926359111 6.443862414730295 0, 3.4524984834739842 6.449338650123927 0, 3.452667296356809 6.450021770598346 0, 3.4531888808856683 6.450372048355996 0, 3.454190651557202 6.4508249065333265 0, 3.455772308693896 6.450871575192487 0, 3.457047310268364 6.450519756958613 0, 3.45872662037407 6.449817195434555 0, 3.460774218852313 6.4490243779130765 0, 3.464109564303319 6.448724925200962 0, 3.4680942602393117 6.4494749402441265 0, 3.468592186996923 6.450683539517145 0, 3.4684384539145245 6.451781480025574 0, 3.4676500456924564 6.455197088118971 0, 3.4669846704134315 6.456713886279312 0, 3.4667861499823065 6.458746121688787 0, 3.4669228528818827 6.459496364558088 0, 3.468771356891279 6.463287666545479 0, 3.4791096534679777 6.483828456285103 0, 3.5209078150969573 6.501751347871943 0, 3.557179818742583 6.509032234616332 0, 3.5992819734831354 6.520174848209958 0, 3.6152370992586396 6.512190230720236 0)	t	[6, 2, 200]	this route operates on a peak period basis and sometimes charter. i think there isnt enough publicity on this route so on some days, it would be a boat or 2 that would be fully loaded for badore, on other days, none at all. 	Sikigha Charity	isikighacharity@gmail.com	6	200	f	f
159	2026-03-04 00:36:25.377	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Covered	Yes	\N	25	2000	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.4419826471853696 6.436702621424786 0, 3.4436653592110664 6.437075409291129 0, 3.4493026815702157 6.437865282686557 0, 3.4523485502550386 6.440174158873675 0, 3.4521199294183154 6.442323956674628 0, 3.452181800257102 6.444257166024714 0, 3.451817342017992 6.4483568313643245 0, 3.452241896666945 6.449680643386397 0, 3.453587510494592 6.450597684973677 0, 3.4545589111715893 6.450914303521753 0, 3.455837331575604 6.450925846197765 0, 3.46042761957912 6.449255203996141 0, 3.4636215222676165 6.448911005550336 0, 3.467704927932634 6.450116159645064 0, 3.46785624977924 6.451545224429635 0, 3.466350663170064 6.45667791076179 0, 3.465956763112453 6.4593973784100704 0, 3.4662379243260233 6.462935263207286 0, 3.463081024247036 6.528017990860386 0, 3.4728735 6.5523891 0)	f	[7, 15]	\N	Israel Ekundayo	israelekundayo@gmail.com	7	15	f	f
24	2026-02-09 11:37:42.522	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana	Yes	Yes	30	2000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.359173482534807 6.439064428506866 0, 3.3604843286442487 6.437676478675207 0, 3.3616008244369153 6.436363080765332 0, 3.3629146276216098 6.4348346448196665 0, 3.3639865701318974 6.4336224415737755 0, 3.3652027572085723 6.43254241779938 0, 3.3661366040292973 6.432138780507608 0, 3.367443002471636 6.4316036908284895 0, 3.3685678157163617 6.431311352388942 0, 3.370501864170248 6.431330360461018 0, 3.3756960431041736 6.433680608105894 0, 3.380714620817125 6.435655420531615 0, 3.394534485200914 6.431705742505199 0, 3.3988433286005932 6.430774164722624 0, 3.4005809330729564 6.424306607089957 0, 3.399242340065401 6.41386250983842 0, 3.398571008204439 6.4062663023015425 0, 3.397843106168742 6.399206848658832 0, 3.397508311664364 6.398910689629854 0, 3.3972196072351206 6.3993744044393805 0, 3.396623767474978 6.401045927170438 0)	f	[10, 130]	\N	Adesina Ayomide 	Adesinaayomide3004@yahoo.com 	10	130	f	f
121	2026-02-27 11:36:31.736	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	35	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.294149195 6.474484688 0, 3.29503533472423 6.473551043665433 0, 3.2982122188377074 6.468620909740463 0, 3.300872568738685 6.46427864074641 0, 3.30513272647225 6.461162873168463 0, 3.3077365607099587 6.459065680685751 0, 3.313024367445412 6.452378008611597 0, 3.3179406913927583 6.43893069242821 0, 3.319927269064227 6.433940831405723 0, 3.319068431176726 6.432811755964513 0, 3.310792342 6.437342371 0)	t	[36, 101, 92]	\N	Sikigha Charity	isikighacharity@gmail.com	36	92	f	f
165	2026-03-06 14:12:38.091	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	Yes	\N	5	200	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.3493182595578617 6.422183975855731 0, 3.3477947223932745 6.426301153186884 0)	f	[78, 84]	\N	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	78	84	f	f
90	2026-02-25 09:35:59.506	LagFerry/Government: Operated by the government	Cash, Cowry card	Catamaran, Speed boats	\N	\N	40	3000	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.6152373048713784 6.512190235933443 0, 3.5995222472382022 6.521157931268647 0, 3.556492646383738 6.51089830648042 0, 3.5199947801515648 6.503825221986007 0, 3.5000543268355098 6.495873770170193 0, 3.477666689790217 6.485553016251792 0, 3.4681417258979486 6.461669540921629 0, 3.4672572287521977 6.459823157630989 0, 3.4679468834965386 6.456299887122844 0, 3.4689499000525723 6.450722255803528 0, 3.46841653351062 6.449394881813557 0, 3.464109564303319 6.448484749530905 0, 3.460371377262751 6.44886426090558 0, 3.458511771526834 6.449737137067338 0, 3.457088603871795 6.450458208679223 0, 3.455741338491692 6.450799768916433 0, 3.454242268561718 6.450742842210231 0, 3.453426319106163 6.450382306404288 0, 3.452667296356809 6.450021770598346 0, 3.452591394081874 6.449338650123927 0, 3.452762174200478 6.443759832916176 0, 3.452305327720838 6.440872262549842 0, 3.4517600465674207 6.44041287261651 0, 3.4489514224324176 6.438568963822696 0, 3.445227667103255 6.437617514059485 0, 3.4431819296734303 6.437749621236024 0, 3.439678972282833 6.4398649779838895 0, 3.435696286029653 6.441861263833 0, 3.430404905284351 6.441843603832906 0, 3.427175929330542 6.442095819404855 0)	t	[200, 2]	This  boat can move twice on Mondays but other weekdays is just once 	Mr Haruna deji 	Harunadeji05@gmail.com	200	2	f	f
72	2026-02-20 12:12:00.217	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Catamaran, Covered, Banana	Yes	\N	45	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.441982008903595 6.436703143129123 0, 3.4436723731694787 6.437046811544366 0, 3.4493453782957766 6.43776755553403 0, 3.452445226354998 6.440125413678583 0, 3.452895711656537 6.4444242534317855 0, 3.452591394081874 6.449338650123927 0, 3.453365717067803 6.450261869593485 0, 3.454399833861562 6.450706711196459 0, 3.455547411968639 6.4508961182622 0, 3.4571370855028922 6.450337771892052 0, 3.4603350160395987 6.448695648878683 0, 3.464109564303319 6.448352268536865 0, 3.4681309163340464 6.449602209922105 0, 3.46880703584504 6.450683539517145 0, 3.4671884381235296 6.4570939819717434 0, 3.4665330084280246 6.458769543949753 0, 3.467863763780668 6.461793344595175 0, 3.469690136601712 6.465039595395371 0, 3.4783172665619215 6.48478434606249 0, 3.5005036119888184 6.495027062974075 0, 3.52047048936637 6.502692439003338 0, 3.5569225026536273 6.510013503085395 0, 3.599435013678392 6.520679855749293 0, 3.6152369945644622 6.512190390299193 0)	f	[7, 200]	 N/A	Sikigha Charity	isikighacharity@gmail.com	7	200	f	f
140	2026-02-27 21:25:24.138	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Fibre boat	No	Yes	5	150	Yes, this route gets disrupted BUT still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.343401869491687 6.435336103180063 0, 3.344153932899125 6.43687156597025 0)	f	[55, 75]	8 entities under NIWA's authority control this place. On weekends, they close by 9:00 pm	Ayodeji Adesegun	ayodejiadesegun20@gmail.com	55	75	f	f
46	2026-02-11 13:14:26.419	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash, Bank Transfer	Banana, Wooden boats	Yes	\N	40	1500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats continue, unless rain is heavy enough to impact navigation or cause safety issues.	LineString Z (3.2055781 6.453045 0, 3.2133758708961153 6.4439992753856155 0, 3.220108632495032 6.436897635382269 0, 3.2294659393105793 6.432677843061942 0, 3.2353004716561915 6.429666280469933 0, 3.2388192004819505 6.428457394968772 0, 3.2426417185899803 6.426160799892964 0, 3.2435887762655544 6.422754876026199 0, 3.243480210162973 6.420804812931879 0, 3.2431011881352956 6.419185098401302 0, 3.2431638017557427 6.418033063984844 0, 3.243134865272293 6.417171543081243 0, 3.242400989331251 6.416903162902312 0, 3.236747347 6.417336462 0)	f	[9, 74]	The peak periods happen when they have parties	Mr Pascal	N/A	9	74	f	f
103	2026-02-25 18:21:35.696	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Banana, Covered	Yes	\N	50	3500	Yes, this route gets disrupted BUT still works during the water hyacinth season	Only covered boats continue, unless heavy enough to impact navigation or cause safety issues.	LineString Z (3.6361133776478773 6.571324058042505 0, 3.6364410992661482 6.570517205299881 0, 3.636850284520597 6.569587298005848 0, 3.637711207682802 6.568912029991193 0, 3.638554422911626 6.56795529496681 0, 3.6392599102685477 6.566969537705788 0, 3.639868788042304 6.56552396324178 0, 3.639942000847636 6.564817244105014 0, 3.6401127984504407 6.564116797159597 0, 3.640137491353304 6.563726156779717 0, 3.6402383494264763 6.563139200510612 0, 3.640618345248004 6.562284191067973 0, 3.640788167076506 6.56175669948802 0, 3.640977463371349 6.561320710031739 0, 3.6406513064532398 6.5594992354930355 0, 3.6378635418473104 6.553240658637177 0, 3.5608503479673628 6.52834850871486 0, 3.474683673103219 6.4881209862702836 0, 3.389826339956497 6.4672000326018475 0, 3.3824784268227193 6.462734251023672 0, 3.380948205040011 6.462328890415979 0, 3.37944097444534 6.4619783201816 0, 3.3793270599893406 6.456921465295597 0, 3.380500539105184 6.453425670147038 0, 3.3829436810600813 6.451568610830791 0, 3.3897127927105384 6.44920784535947 0)	t	[58, 1, 6]	\N	Sikigha Charity	isikighacharity@gmail.com	58	6	f	f
162	2026-03-05 03:21:16.052	Formal Commercial: Operated by licensed operators (under the jurisdiction/licensed by LASWA or NIWA)	Cash	Wooden boats, Fibre boat	Yes	\N	15	500	No, this route doesn't get disrupted and still works during the water hyacinth season	All boats are suspended.	LineString Z (3.3521236826844127 6.424158898708965 0, 3.3550139922474087 6.426552125086341 0, 3.358149104682693 6.428519730888787 0, 3.359255052254533 6.427659863511215 0, 3.3644467344529296 6.432523903419837 0, 3.3591730805353257 6.439064008253442 0)	t	[64, 85, 10]	\N	Israel Ekundayo	israelekundayo@gmail.com	64	10	f	f
\.


--
-- Data for Name: routes_gtfs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.routes_gtfs (generated_at, route_id, agency_id, route_short_name, route_long_name, route_type) FROM stdin;
2026-05-19 14:13:19.872748	R4	LASWA	F2 - F14	Five Cowries/Falomo (Ikoyi) to Offin, Ikorodu (Formal Commercial)	4
2026-05-19 14:13:19.872748	R8	LASWA	F3 - F2	Ikorodu/Ipakodo Ferry Terminal to Five Cowries/Falomo (Ikoyi) (LagFerry/Government)	4
2026-05-19 14:13:19.872748	R9	LASWA	F3 - F5	Ikorodu/Ipakodo Ferry Terminal to Flour Mills (Apapa) (LagFerry/Government)	4
2026-05-19 14:13:19.872748	R10	LASWA	F3 - F10	Ikorodu/Ipakodo Ferry Terminal to Liverpool (Apapa) (LagFerry/Government)	4
2026-05-19 14:13:19.872748	R11	LASWA	F3 - F2	Ikorodu/Ipakodo Ferry Terminal to Five Cowries/Falomo (Ikoyi) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R12	LASWA	F27 - F99	Allens Unit/Alex (Apapa) to Manager (Formal Commercial)	4
2026-05-19 14:13:19.872748	R13	LASWA	F27 - F91	Allens Unit/Alex (Apapa) to KabaKaba (Formal Commercial)	4
2026-05-19 14:13:19.872748	R14	LASWA	F27 - F121	Allens Unit/Alex (Apapa) to Sagbokoji (Formal Commercial)	4
2026-05-19 14:13:19.872748	R16	LASWA	F10 - F121	Liverpool (Apapa) to Sagbokoji (Formal Commercial)	4
2026-05-19 14:13:19.872748	R17	LASWA	F10 - F200	Liverpool (Apapa) to Badore Ferry Terminal (LagFerry/Government)	4
2026-05-19 14:13:19.872748	R19	LASWA	F10 - F35	Liverpool (Apapa) to Boundary (Apapa)/Number 3 (Apapa) Waterside (Formal Commercial)	4
2026-05-19 14:13:19.872748	R23	LASWA	F10 - F57	Liverpool (Apapa) to Gbaji Yekeme Jetty (Formal Commercial)	4
2026-05-19 14:13:19.872748	R24	LASWA	F10 - F130	Liverpool (Apapa) to Tarkwa Bay (Formal Commercial)	4
2026-05-19 14:13:19.872748	R25	LASWA	F38 - F67	Coconut Landing to Igbologun/Snake Island (Formal Commercial)	4
2026-05-19 14:13:19.872748	R27	LASWA	F70 - F30	Ijegun Egba to Baba Shino (Formal Commercial)	4
2026-05-19 14:13:19.872748	R28	LASWA	F70 - F125	Ijegun Egba to Second Rainbow Landing (Formal Commercial)	4
2026-05-19 14:13:19.872748	R29	LASWA	F70 - F59	Ijegun Egba to Ibasa (Formal Commercial)	4
2026-05-19 14:13:19.872748	R30	LASWA	F70 - F62	Ijegun Egba to Ibeshe Palace (Formal Commercial)	4
2026-05-19 14:13:19.872748	R31	LASWA	F18 - F4	Abule Osun to Port Novo (Benin Republic) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R33	LASWA	F18 - F80	Abule Osun to Irede (Formal Commercial)	4
2026-05-19 14:13:19.872748	R34	LASWA	F15 - F2	Ibeshe/Thesaurus Ferry Terminal to Five Cowries/Falomo (Ikoyi) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R36	LASWA	F15 - F10	Ibeshe/Thesaurus Ferry Terminal to Liverpool (Apapa) (LagFerry/Government)	4
2026-05-19 14:13:19.872748	R37	LASWA	F14 - F2	Offin, Ikorodu to Five Cowries/Falomo (Ikoyi) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R38	LASWA	F69 - F8	Ijede/Tarzan to Badore Jetty (Tarzan) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R40	LASWA	F69 - F2	Ijede/Tarzan to Five Cowries/Falomo (Ikoyi) (LagFerry/Government)	4
2026-05-19 14:13:19.872748	R41	LASWA	F109 - F31	Oke Ira Nla (Ajah) to Baiyeku (Formal Commercial)	4
2026-05-19 14:13:19.872748	R43	LASWA	F71 - F144	Ijon to Ijon Odo (Ogun) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R44	LASWA	F63 - F145	Igando Landing/Isuti to Oto Owu Odo (Ogun) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R45	LASWA	F9 - F81	Ebute Ojo/Sifax Ferry Terminal to Irewe Ojo (Formal Commercial)	4
2026-05-19 14:13:19.872748	R46	LASWA	F9 - F74	Ebute Ojo/Sifax Ferry Terminal to Ikare town landing (Formal Commercial)	4
2026-05-19 14:13:19.872748	R47	LASWA	F9 - F77	Ebute Ojo/Sifax Ferry Terminal to Ilashe (Formal Commercial)	4
2026-05-19 14:13:19.872748	R48	LASWA	F9 - F19	Ebute Ojo/Sifax Ferry Terminal to Agaja (Formal Commercial)	4
2026-05-19 14:13:19.872748	R49	LASWA	F9 - F6	Ebute Ojo/Sifax Ferry Terminal to Marina/CMS (LagFerry/Government)	4
2026-05-19 14:13:19.872748	R50	LASWA	F23 - F20	Agboyi Ketu to Agboyi 3 (Formal Commercial)	4
2026-05-19 14:13:19.872748	R53	LASWA	F51 - F141	Etegbin to Isofin (Formal Commercial)	4
2026-05-19 14:13:19.872748	R54	LASWA	F83 - F142	Isashi Landing to Itekun (Ogun) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R63	LASWA	F10 - F85	Liverpool (Apapa) to Itun Agan (Formal Commercial)	4
2026-05-19 14:13:19.872748	R64	LASWA	F10 - F84	Liverpool (Apapa) to Isoda (Formal Commercial)	4
2026-05-19 14:13:19.872748	R65	LASWA	F107 - F77	Ojo market waterside to Ilashe (Formal Commercial)	4
2026-05-19 14:13:19.872748	R66	LASWA	F89 - F107	Iyagbe to Ojo market waterside (Formal Commercial)	4
2026-05-19 14:13:19.872748	R67	LASWA	F73 - F107	Ikare palace to Ojo market waterside (Formal Commercial)	4
2026-05-19 14:13:19.872748	R68	LASWA	F74 - F107	Ikare town landing to Ojo market waterside (Formal Commercial)	4
2026-05-19 14:13:19.872748	R71	LASWA	F60 - F70	Ibese to Ijegun Egba (Formal Commercial)	4
2026-05-19 14:13:19.872748	R72	LASWA	F7 - F200	Addax/Sandfill/Maroko (Victoria Island) to Badore Ferry Terminal (Formal Commercial)	4
2026-05-19 14:13:19.872748	R73	LASWA	F7 - F3	Addax/Sandfill/Maroko (Victoria Island) to Ikorodu/Ipakodo Ferry Terminal (Formal Commercial)	4
2026-05-19 14:13:19.872748	R74	LASWA	F7 - F31	Addax/Sandfill/Maroko (Victoria Island) to Baiyeku (Formal Commercial)	4
2026-05-19 14:13:19.872748	R75	LASWA	F5 - F3	Flour Mills (Apapa) to Ikorodu/Ipakodo Ferry Terminal (Formal Commercial)	4
2026-05-19 14:13:19.872748	R76	LASWA	F5 - F6	Flour Mills (Apapa) to Marina/CMS (Formal Commercial)	4
2026-05-19 14:13:19.872748	R77	LASWA	F36 - F101	Capital Oil/FESTAC to Mile 2/NIWA (Formal Commercial)	4
2026-05-19 14:13:19.872748	R89	LASWA	F200 - F69	Badore Ferry Terminal to Ijede/Tarzan (Formal Commercial)	4
2026-05-19 14:13:19.872748	R90	LASWA	F200 - F2	Badore Ferry Terminal to Five Cowries/Falomo (Ikoyi) (LagFerry/Government)	4
2026-05-19 14:13:19.872748	R91	LASWA	F200 - F58	Badore Ferry Terminal to Gberigbe (Formal Commercial)	4
2026-05-19 14:13:19.872748	R92	LASWA	F200 - F86	Badore Ferry Terminal to Itomu Jetty (Formal Commercial)	4
2026-05-19 14:13:19.872748	R94	LASWA	F86 - F152	Itomu Jetty to Kabiyesi itomu jetty (Formal Commercial)	4
2026-05-19 14:13:19.872748	R95	LASWA	F46 - F153	Epe Ayetoro Jetty to Ipare (Ondo) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R96	LASWA	F46 - F154	Epe Ayetoro Jetty to Iwopin (Ogun) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R97	LASWA	F46 - F17	Epe Ayetoro Jetty to Abomiti-Nla Epe (Formal Commercial)	4
2026-05-19 14:13:19.872748	R98	LASWA	F46 - F155	Epe Ayetoro Jetty to Eyin Osa (Formal Commercial)	4
2026-05-19 14:13:19.872748	R103	LASWA	F58 - F6	Gberigbe to Marina/CMS (Formal Commercial)	4
2026-05-19 14:13:19.872748	R107	LASWA	F42 - F6	Egbin to Marina/CMS (Formal Commercial)	4
2026-05-19 14:13:19.872748	R108	LASWA	F92 - F6	Kirikiri to Marina/CMS (Formal Commercial)	4
2026-05-19 14:13:19.872748	R109	LASWA	F92 - F101	Kirikiri to Mile 2/NIWA (Formal Commercial)	4
2026-05-19 14:13:19.872748	R111	LASWA	F107 - F77	Ojo market waterside to Ilashe (Formal Commercial)	4
2026-05-19 14:13:19.872748	R112	LASWA	F107 - F60	Ojo market waterside to Ibese (Formal Commercial)	4
2026-05-19 14:13:19.872748	R113	LASWA	F107 - F74	Ojo market waterside to Ikare town landing (Formal Commercial)	4
2026-05-19 14:13:19.872748	R115	LASWA	F107 - F19	Ojo market waterside to Agaja (Formal Commercial)	4
2026-05-19 14:13:19.872748	R116	LASWA	F92 - F4	Kirikiri to Port Novo (Benin Republic) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R121	LASWA	F36 - F92	Capital Oil/FESTAC to Kirikiri (Formal Commercial)	4
2026-05-19 14:13:19.872748	R122	LASWA	F36 - F10	Capital Oil/FESTAC to Liverpool (Apapa) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R123	LASWA	F92 - F70	Kirikiri to Ijegun Egba (Formal Commercial)	4
2026-05-19 14:13:19.872748	R124	LASWA	F6 - F3	Marina/CMS to Ikorodu/Ipakodo Ferry Terminal (Formal Commercial)	4
2026-05-19 14:13:19.872748	R125	LASWA	F6 - F130	Marina/CMS to Tarkwa Bay (Formal Commercial)	4
2026-05-19 14:13:19.872748	R126	LASWA	F6 - F4	Marina/CMS to Port Novo (Benin Republic) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R128	LASWA	F6 - F10	Marina/CMS to Liverpool (Apapa) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R129	LASWA	F6 - F121	Marina/CMS to Sagbokoji (Formal Commercial)	4
2026-05-19 14:13:19.872748	R131	LASWA	F124 - F104	Second Badagry to Number 1A Waterside (Informal Commercial)	4
2026-05-19 14:13:19.872748	R132	LASWA	F102 - F104	Mogaji (Ajegunle) to Number 1A Waterside (Informal Commercial)	4
2026-05-19 14:13:19.872748	R135	LASWA	F105 - F147	Number 2 (Apapa) Waterside to Number 2 (Ajegunle) Waterside/Kumuyi Street(Ajegunle) (Informal Commercial)	4
2026-05-19 14:13:19.872748	R136	LASWA	F6 - F200	Marina/CMS to Badore Ferry Terminal (Formal Commercial)	4
2026-05-19 14:13:19.872748	R138	LASWA	F35 - F16	Boundary (Apapa)/Number 3 (Apapa) Waterside to Number 3 (Ajegunle) Waterside (Informal Commercial)	4
2026-05-19 14:13:19.872748	R140	LASWA	F55 - F75	First Gate (Tin Can Island) to IKO/Temidire (Formal Commercial)	4
2026-05-19 14:13:19.872748	R142	LASWA	F149 - F151	Number 1 (Ajegunle) Waterside to Number 1 (Apapa) Waterside (Informal Commercial)	4
2026-05-19 14:13:19.872748	R144	LASWA	F101 - F4	Mile 2/NIWA to Port Novo (Benin Republic) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R148	LASWA	F60 - F107	Ibese to Ojo market waterside (Formal Commercial)	4
2026-05-19 14:13:19.872748	R149	LASWA	F129 - F24	Itomoro to Agojedo/Agbejedo (Formal Commercial)	4
2026-05-19 14:13:19.872748	R154	LASWA	F6 - F106	Marina/CMS to Ogogoro Village (Formal Commercial)	4
2026-05-19 14:13:19.872748	R155	LASWA	F42 - F6	Egbin to Marina/CMS (Formal Commercial)	4
2026-05-19 14:13:19.872748	R156	LASWA	F4 - F1	Port Novo (Benin Republic) to Ebute Ero/Elegbata Jetty (Formal Commercial)	4
2026-05-19 14:13:19.872748	R157	LASWA	F156 - F1	Farasime to Ebute Ero/Elegbata Jetty (Formal Commercial)	4
2026-05-19 14:13:19.872748	R158	LASWA	F88 - F157	Iya Afin Jetty to Izigi (Ogun) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R159	LASWA	F7 - F15	Addax/Sandfill/Maroko (Victoria Island) to Ibeshe/Thesaurus Ferry Terminal (Formal Commercial)	4
2026-05-19 14:13:19.872748	R160	LASWA	F7 - F14	Addax/Sandfill/Maroko (Victoria Island) to Offin, Ikorodu (Formal Commercial)	4
2026-05-19 14:13:19.872748	R161	LASWA	F7 - F69	Addax/Sandfill/Maroko (Victoria Island) to Ijede/Tarzan (Formal Commercial)	4
2026-05-19 14:13:19.872748	R162	LASWA	F64 - F10	Igbo Elejo to Liverpool (Apapa) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R163	LASWA	F64 - F84	Igbo Elejo to Isoda (Formal Commercial)	4
2026-05-19 14:13:19.872748	R164	LASWA	F84 - F10	Isoda to Liverpool (Apapa) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R165	LASWA	F78 - F84	Ilutuntun to Isoda (Formal Commercial)	4
2026-05-19 14:13:19.872748	R166	LASWA	F129 - F10	Itomoro to Liverpool (Apapa) (Formal Commercial)	4
2026-05-19 14:13:19.872748	R168	LASWA	F81 - F107	Irewe Ojo to Ojo market waterside (Formal Commercial)	4
2026-05-19 14:13:19.872748	R170	LASWA	F54 - F130	Fiki Marine (Victoria Island) to Tarkwa Bay (Formal Commercial)	4
2026-05-19 14:13:19.872748	R179	LASWA	F23 - F22	Agboyi Ketu to Oko Agbon (Informal Commercial)	4
2026-05-19 14:13:19.872748	R180	LASWA	F51 - F41	Etegbin to Egan Landing (Formal Commercial)	4
2026-05-19 14:13:19.872748	R181	LASWA	F79 - F222	Imore Waterside to Imore Community (Informal Commercial)	4
\.


--
-- Data for Name: shapes_gtfs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.shapes_gtfs (generated_at, shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence) FROM stdin;
2026-05-19 14:13:19.872748	S4	6.442095174	3.427179994	1
2026-05-19 14:13:19.872748	S4	6.442022813155185	3.430349916181143	2
2026-05-19 14:13:19.872748	S4	6.442191379059877	3.435710521305812	3
2026-05-19 14:13:19.872748	S4	6.441659011870856	3.4371876354201163	4
2026-05-19 14:13:19.872748	S4	6.440410320841825	3.4399969986244896	5
2026-05-19 14:13:19.872748	S4	6.438064502707718	3.4432902916822505	6
2026-05-19 14:13:19.872748	S4	6.437951952707851	3.4452381678590798	7
2026-05-19 14:13:19.872748	S4	6.4388927759818015	3.4487696164089496	8
2026-05-19 14:13:19.872748	S4	6.440630363266215	3.451393410980398	9
2026-05-19 14:13:19.872748	S4	6.44098842059255	3.452119474852506	10
2026-05-19 14:13:19.872748	S4	6.441569210806088	3.452258864503755	11
2026-05-19 14:13:19.872748	S4	6.443567129140662	3.452514412197712	12
2026-05-19 14:13:19.872748	S4	6.44486041590274	3.452420613963269	13
2026-05-19 14:13:19.872748	S4	6.448636554080776	3.452192907138463	14
2026-05-19 14:13:19.872748	S4	6.450040746167081	3.452496516238204	15
2026-05-19 14:13:19.872748	S4	6.450439233110491	3.453179636712623	16
2026-05-19 14:13:19.872748	S4	6.450856695622636	3.453824806049574	17
2026-05-19 14:13:19.872748	S4	6.451008500172505	3.454887437898669	18
2026-05-19 14:13:19.872748	S4	6.451046451309973	3.455703387354224	19
2026-05-19 14:13:19.872748	S4	6.450837720053902	3.456348556691175	20
2026-05-19 14:13:19.872748	S4	6.450116648442015	3.458625624939237	21
2026-05-19 14:13:19.872748	S4	6.449490454673799	3.460200597144147	22
2026-05-19 14:13:19.872748	S4	6.449338650123928	3.46228790970487	23
2026-05-19 14:13:19.872748	S4	6.449277731113232	3.465565866469349	24
2026-05-19 14:13:19.872748	S4	6.449941585081747	3.468026031176199	25
2026-05-19 14:13:19.872748	S4	6.451074041851566	3.468182232109967	26
2026-05-19 14:13:19.872748	S4	6.452792252123016	3.467947930709315	27
2026-05-19 14:13:19.872748	S4	6.454119960060046	3.467635528841778	28
2026-05-19 14:13:19.872748	S4	6.457009677334758	3.466659273005727	29
2026-05-19 14:13:19.872748	S4	6.459079339707188	3.466464021838517	30
2026-05-19 14:13:19.872748	S4	6.462746831441437	3.466422591010072	31
2026-05-19 14:13:19.872748	S4	6.481922133147788	3.466440812907292	32
2026-05-19 14:13:19.872748	S4	6.496023679655265	3.466499213955513	33
2026-05-19 14:13:19.872748	S4	6.5393273	3.5010197	34
2026-05-19 14:13:19.872748	S8	6.601832	3.4862304	1
2026-05-19 14:13:19.872748	S8	6.584248038327353	3.478228496825832	2
2026-05-19 14:13:19.872748	S8	6.545684635523536	3.4569869615537536	3
2026-05-19 14:13:19.872748	S8	6.4646156990758605	3.4648538004672886	4
2026-05-19 14:13:19.872748	S8	6.457076872637717	3.465193012934924	5
2026-05-19 14:13:19.872748	S8	6.455239964720791	3.465374789104149	6
2026-05-19 14:13:19.872748	S8	6.453693420659534	3.4656442305715127	7
2026-05-19 14:13:19.872748	S8	6.452624029445177	3.4660644819424045	8
2026-05-19 14:13:19.872748	S8	6.451809985414929	3.4661861514235768	9
2026-05-19 14:13:19.872748	S8	6.4511120883416515	3.4658841052939273	10
2026-05-19 14:13:19.872748	S8	6.449881435433807	3.4636824129728243	11
2026-05-19 14:13:19.872748	S8	6.449784133147343	3.462310352929126	12
2026-05-19 14:13:19.872748	S8	6.449982294866626	3.4598271842834762	13
2026-05-19 14:13:19.872748	S8	6.450136901329213	3.4580453380262925	14
2026-05-19 14:13:19.872748	S8	6.450405869405844	3.456446096600939	15
2026-05-19 14:13:19.872748	S8	6.45054086180561	3.455451968688856	16
2026-05-19 14:13:19.872748	S8	6.4504101963342215	3.4542739666005366	17
2026-05-19 14:13:19.872748	S8	6.450039599279447	3.4534333458584756	18
2026-05-19 14:13:19.872748	S8	6.449636655130944	3.4531316251712507	19
2026-05-19 14:13:19.872748	S8	6.448325046638855	3.453073181638116	20
2026-05-19 14:13:19.872748	S8	6.444360299043453	3.4533534504839283	21
2026-05-19 14:13:19.872748	S8	6.442226121022745	3.453163694796562	22
2026-05-19 14:13:19.872748	S8	6.439899795560487	3.452852493984118	23
2026-05-19 14:13:19.872748	S8	6.437405975143271	3.449508938510678	24
2026-05-19 14:13:19.872748	S8	6.43684487617933	3.443724633133639	25
2026-05-19 14:13:19.872748	S8	6.436702999528588	3.441982126255169	26
2026-05-19 14:13:19.872748	S8	6.4385670468869645	3.440078697608401	27
2026-05-19 14:13:19.872748	S8	6.441392690971519	3.435853440367354	28
2026-05-19 14:13:19.872748	S8	6.441445773552735	3.4356648927168383	29
2026-05-19 14:13:19.872748	S8	6.441583139796554	3.4296424338548666	30
2026-05-19 14:13:19.872748	S8	6.442095174	3.427179994	31
2026-05-19 14:13:19.872748	S9	6.601832	3.4862304	1
2026-05-19 14:13:19.872748	S9	6.587861802162575	3.4752106563543474	2
2026-05-19 14:13:19.872748	S9	6.549709647042801	3.4502330993444277	3
2026-05-19 14:13:19.872748	S9	6.51525094157288	3.4258333213746655	4
2026-05-19 14:13:19.872748	S9	6.490042834988112	3.402869426193956	5
2026-05-19 14:13:19.872748	S9	6.463432525332177	3.3830376165132807	6
2026-05-19 14:13:19.872748	S9	6.462734506635153	3.382478301866796	7
2026-05-19 14:13:19.872748	S9	6.462675988078655	3.381403492985905	8
2026-05-19 14:13:19.872748	S9	6.462280507457692	3.3792338207578236	9
2026-05-19 14:13:19.872748	S9	6.45687139915713	3.3786713553347925	10
2026-05-19 14:13:19.872748	S9	6.453092100262134	3.379861675457275	11
2026-05-19 14:13:19.872748	S9	6.451052821660096	3.3825914299988242	12
2026-05-19 14:13:19.872748	S9	6.449710980073286	3.3861241115506617	13
2026-05-19 14:13:19.872748	S9	6.449208079780339	3.3897130787985748	14
2026-05-19 14:13:19.872748	S9	6.448236399786917	3.3785629830923933	15
2026-05-19 14:13:19.872748	S9	6.4477052	3.3749219	16
2026-05-19 14:13:19.872748	S10	6.601832	3.4862304	1
2026-05-19 14:13:19.872748	S10	6.58749197143752	3.4726187083094504	2
2026-05-19 14:13:19.872748	S10	6.55401865861223	3.4476135020548617	3
2026-05-19 14:13:19.872748	S10	6.5237357731441055	3.426197765416483	4
2026-05-19 14:13:19.872748	S10	6.498660972457295	3.4067343122838443	5
2026-05-19 14:13:19.872748	S10	6.478170749479121	3.3920424339650843	6
2026-05-19 14:13:19.872748	S10	6.47005718219117	3.38620417542527	7
2026-05-19 14:13:19.872748	S10	6.463593839585963	3.379417665689802	8
2026-05-19 14:13:19.872748	S10	6.460133596252768	3.3756102405488226	9
2026-05-19 14:13:19.872748	S10	6.452098598684394	3.374568854999654	10
2026-05-19 14:13:19.872748	S10	6.4382351337867485	3.396634499025992	11
2026-05-19 14:13:19.872748	S10	6.43744450474444	3.3964534267976814	12
2026-05-19 14:13:19.872748	S10	6.4335377	3.3948567	13
2026-05-19 14:13:19.872748	S10	6.4354066	3.3872855	14
2026-05-19 14:13:19.872748	S10	6.436956355530353	3.382306362706959	15
2026-05-19 14:13:19.872748	S10	6.437126261163075	3.381315246516077	16
2026-05-19 14:13:19.872748	S10	6.437041308346714	3.380154224692472	17
2026-05-19 14:13:19.872748	S10	6.4362252	3.3777788	18
2026-05-19 14:13:19.872748	S10	6.432961653190958	3.371224355644744	19
2026-05-19 14:13:19.872748	S10	6.432586247059819	3.370033412056305	20
2026-05-19 14:13:19.872748	S10	6.432612137137829	3.369049589091944	21
2026-05-19 14:13:19.872748	S10	6.432612137137829	3.368285831790663	22
2026-05-19 14:13:19.872748	S10	6.432948708151953	3.36735378898232	23
2026-05-19 14:13:19.872748	S10	6.433272334127072	3.36599455988682	24
2026-05-19 14:13:19.872748	S10	6.4336218501802	3.364946011727434	25
2026-05-19 14:13:19.872748	S10	6.4338936959993	3.364285814738191	26
2026-05-19 14:13:19.872748	S10	6.434366189922974	3.36368387042447	27
2026-05-19 14:13:19.872748	S10	6.435589496108924	3.362654739823592	28
2026-05-19 14:13:19.872748	S10	6.436327363332196	3.362175773380415	29
2026-05-19 14:13:19.872748	S10	6.436560374034281	3.361981597795344	30
2026-05-19 14:13:19.872748	S10	6.4390793	3.3592365	31
2026-05-19 14:13:19.872748	S11	6.601832	3.4862304	1
2026-05-19 14:13:19.872748	S11	6.583197125644056	3.479069999449163	2
2026-05-19 14:13:19.872748	S11	6.545330109131676	3.4581636073752415	3
2026-05-19 14:13:19.872748	S11	6.46082718324549	3.465460092042102	4
2026-05-19 14:13:19.872748	S11	6.4571785	3.4653099	5
2026-05-19 14:13:19.872748	S11	6.454041859593162	3.46576111763656	6
2026-05-19 14:13:19.872748	S11	6.452362699555154	3.466385921371633	7
2026-05-19 14:13:19.872748	S11	6.450995941384682	3.466307820904749	8
2026-05-19 14:13:19.872748	S11	6.44930069898646	3.463141810297893	9
2026-05-19 14:13:19.872748	S11	6.4475959	3.4590768	10
2026-05-19 14:13:19.872748	S11	6.448883236474314	3.458359966976963	11
2026-05-19 14:13:19.872748	S11	6.449832014911006	3.457373237402803	12
2026-05-19 14:13:19.872748	S11	6.450173575148216	3.456709092497118	13
2026-05-19 14:13:19.872748	S11	6.45043923311049	3.455817240766628	14
2026-05-19 14:13:19.872748	S11	6.45043923311049	3.45469768221133	15
2026-05-19 14:13:19.872748	S11	6.450097672873281	3.453710952637171	16
2026-05-19 14:13:19.872748	S11	6.449680210361136	3.452970905456551	17
2026-05-19 14:13:19.872748	S11	6.448484749530904	3.452970905456551	18
2026-05-19 14:13:19.872748	S11	6.444461928959328	3.453236563418824	19
2026-05-19 14:13:19.872748	S11	6.44229871412367	3.453046807731486	20
2026-05-19 14:13:19.872748	S11	6.439860672772989	3.4529322404580616	21
2026-05-19 14:13:19.872748	S11	6.437336068493657	3.4495531366733756	22
2026-05-19 14:13:19.872748	S11	6.436806387015445	3.4437203120600492	23
2026-05-19 14:13:19.872748	S11	6.4367026539256464	3.441982189645216	24
2026-05-19 14:13:19.872748	S11	6.438592865332013	3.4401041221520017	25
2026-05-19 14:13:19.872748	S11	6.4414333800114045	3.435869985424152	26
2026-05-19 14:13:19.872748	S11	6.441495609665203	3.4356621818033526	27
2026-05-19 14:13:19.872748	S11	6.441618604873687	3.4296514397628646	28
2026-05-19 14:13:19.872748	S11	6.442095174	3.427179994	29
2026-05-19 14:13:19.872748	S12	6.4346659	3.3700913	1
2026-05-19 14:13:19.872748	S12	6.429986033	3.370910736	2
2026-05-19 14:13:19.872748	S13	6.4346659	3.3700913	1
2026-05-19 14:13:19.872748	S13	6.4311226	3.3733927	2
2026-05-19 14:13:19.872748	S14	6.4346659	3.3700913	1
2026-05-19 14:13:19.872748	S14	6.43277977	3.376968865	2
2026-05-19 14:13:19.872748	S16	6.4390637347789	3.359173807347691	1
2026-05-19 14:13:19.872748	S16	6.436946750568449	3.361488574218879	2
2026-05-19 14:13:19.872748	S16	6.4345666418436185	3.3632942421516896	3
2026-05-19 14:13:19.872748	S16	6.433376586765089	3.36522052771621	4
2026-05-19 14:13:19.872748	S16	6.4328413828788005	3.3684111828024026	5
2026-05-19 14:13:19.872748	S16	6.433550905544749	3.3698058335616654	6
2026-05-19 14:13:19.872748	S16	6.434538550266627	3.370295825087261	7
2026-05-19 14:13:19.872748	S16	6.433601578458385	3.373043133226452	8
2026-05-19 14:13:19.872748	S16	6.433031169011391	3.3753376188192217	9
2026-05-19 14:13:19.872748	S16	6.432784770773643	3.376979975700015	10
2026-05-19 14:13:19.872748	S17	6.439063929145328	3.359173020483679	1
2026-05-19 14:13:19.872748	S17	6.435667166342952	3.362292278731458	2
2026-05-19 14:13:19.872748	S17	6.433595960102191	3.364052804036106	3
2026-05-19 14:13:19.872748	S17	6.433194663893043	3.364661220869329	4
2026-05-19 14:13:19.872748	S17	6.433000488307972	3.365114297234496	5
2026-05-19 14:13:19.872748	S17	6.432767477605887	3.36545086824862	6
2026-05-19 14:13:19.872748	S17	6.432275566123705	3.366344075939948	7
2026-05-19 14:13:19.872748	S17	6.432029610382615	3.367004272929191	8
2026-05-19 14:13:19.872748	S17	6.431680094329487	3.368195216517629	9
2026-05-19 14:13:19.872748	S17	6.431563588978443	3.370331147953415	10
2026-05-19 14:13:19.872748	S17	6.431848379836548	3.37140558619081	11
2026-05-19 14:13:19.872748	S17	6.433473290059539	3.375793313452592	12
2026-05-19 14:13:19.872748	S17	6.43528561680858	3.381315246516077	13
2026-05-19 14:13:19.872748	S17	6.4335582428759	3.387686707743176	14
2026-05-19 14:13:19.872748	S17	6.431406104861413	3.394596203473896	15
2026-05-19 14:13:19.872748	S17	6.433119215609712	3.3971791842365153	16
2026-05-19 14:13:19.872748	S17	6.438607102664451	3.398499957838382	17
2026-05-19 14:13:19.872748	S17	6.449208114885105	3.3897126633874217	18
2026-05-19 14:13:19.872748	S17	6.4422428670775735	3.3986144746746314	19
2026-05-19 14:13:19.872748	S17	6.439913772187001	3.4013770107537047	20
2026-05-19 14:13:19.872748	S17	6.439538831803817	3.401889597480791	21
2026-05-19 14:13:19.872748	S17	6.439365821095312	3.402215553399695	22
2026-05-19 14:13:19.872748	S17	6.439403763518911	3.4024311545771213	23
2026-05-19 14:13:19.872748	S17	6.440089256695017	3.4030431812002355	24
2026-05-19 14:13:19.872748	S17	6.441820315752079	3.404848856056453	25
2026-05-19 14:13:19.872748	S17	6.442015648412774	3.40597988011192	26
2026-05-19 14:13:19.872748	S17	6.442045971400944	3.407969011976958	27
2026-05-19 14:13:19.872748	S17	6.441082862901814	3.4108889186863904	28
2026-05-19 14:13:19.872748	S17	6.43846648329669	3.4160541162147204	29
2026-05-19 14:13:19.872748	S17	6.438109153269481	3.4181928607335674	30
2026-05-19 14:13:19.872748	S17	6.439098175880853	3.42178772471214	31
2026-05-19 14:13:19.872748	S17	6.441035265795154	3.425017651544929	32
2026-05-19 14:13:19.872748	S17	6.442095819404855	3.427175929330542	33
2026-05-19 14:13:19.872748	S17	6.44188397758475	3.4303753248264597	34
2026-05-19 14:13:19.872748	S17	6.441937450564477	3.435703490775111	35
2026-05-19 14:13:19.872748	S17	6.441297643069623	3.4371147390907995	36
2026-05-19 14:13:19.872748	S17	6.440005894699184	3.439745028102815	37
2026-05-19 14:13:19.872748	S17	6.437825499151374	3.443204916649234	38
2026-05-19 14:13:19.872748	S17	6.43768592593405	3.4452220458414486	39
2026-05-19 14:13:19.872748	S17	6.438654957592255	3.448906466453445	40
2026-05-19 14:13:19.872748	S17	6.440445613165541	3.451668881769882	41
2026-05-19 14:13:19.872748	S17	6.440872262549842	3.452305327720838	42
2026-05-19 14:13:19.872748	S17	6.443759832916176	3.452762174200478	43
2026-05-19 14:13:19.872748	S17	6.449338650123927	3.452591394081874	44
2026-05-19 14:13:19.872748	S17	6.450021770598346	3.452667296356809	45
2026-05-19 14:13:19.872748	S17	6.450382306404288	3.453426319106163	46
2026-05-19 14:13:19.872748	S17	6.450742842210231	3.454242268561718	47
2026-05-19 14:13:19.872748	S17	6.450799768916433	3.455741338491692	48
2026-05-19 14:13:19.872748	S17	6.450458208679223	3.457088603871795	49
2026-05-19 14:13:19.872748	S17	6.449737137067338	3.458511771526834	50
2026-05-19 14:13:19.872748	S17	6.44886426090558	3.460371377262751	51
2026-05-19 14:13:19.872748	S17	6.448484749530905	3.464109564303319	52
2026-05-19 14:13:19.872748	S17	6.449394881813557	3.46841653351062	53
2026-05-19 14:13:19.872748	S17	6.450683539517145	3.46880703584504	54
2026-05-19 14:13:19.872748	S17	6.452128398154501	3.468572734444388	55
2026-05-19 14:13:19.872748	S17	6.45533051729675	3.468026031176199	56
2026-05-19 14:13:19.872748	S17	6.457009677334758	3.46747932790801	57
2026-05-19 14:13:19.872748	S17	6.458610906432366	3.4669498386330364	58
2026-05-19 14:13:19.872748	S17	6.461656655114363	3.46767457907522	59
2026-05-19 14:13:19.872748	S17	6.463531565247443	3.4686873539393	60
2026-05-19 14:13:19.872748	S17	6.464961518774142	3.469307141996355	61
2026-05-19 14:13:19.872748	S17	6.487302156484713	3.4759185847219056	62
2026-05-19 14:13:19.872748	S17	6.497584352778277	3.499279179003224	63
2026-05-19 14:13:19.872748	S17	6.505582945169733	3.5194671504937913	64
2026-05-19 14:13:19.872748	S17	6.512318162809499	3.555977264714066	65
2026-05-19 14:13:19.872748	S17	6.522302700859115	3.59975152043511	66
2026-05-19 14:13:19.872748	S17	6.512190772414368	3.615237079363986	67
2026-05-19 14:13:19.872748	S19	6.439064183735342	3.3591733715160426	1
2026-05-19 14:13:19.872748	S19	6.439594492712476	3.356829582371355	2
2026-05-19 14:13:19.872748	S19	6.439427348685829	3.355438129201781	3
2026-05-19 14:13:19.872748	S19	6.439082041257653	3.3540080948982025	4
2026-05-19 14:13:19.872748	S19	6.43788989388192	3.3515069341547616	5
2026-05-19 14:13:19.872748	S19	6.4369464015389255	3.349280310206545	6
2026-05-19 14:13:19.872748	S19	6.437257314412614	3.349168982656728	7
2026-05-19 14:13:19.872748	S19	6.438300463791504	3.349115969538495	8
2026-05-19 14:13:19.872748	S19	6.439244036657316	3.3491009592150194	9
2026-05-19 14:13:19.872748	S19	6.443664793371199	3.349265503813207	10
2026-05-19 14:13:19.872748	S19	6.444569976704161	3.3494544645639412	11
2026-05-19 14:13:19.872748	S19	6.446510833747375	3.3504115957878566	12
2026-05-19 14:13:19.872748	S19	6.448748074620233	3.3513312088760943	13
2026-05-19 14:13:19.872748	S19	6.44971638807712	3.3514861604728243	14
2026-05-19 14:13:19.872748	S19	6.4503921270555615	3.3515763778302703	15
2026-05-19 14:13:19.872748	S23	6.439065516882735	3.3591726742562287	1
2026-05-19 14:13:19.872748	S23	6.4331370060584305	3.363690943422938	2
2026-05-19 14:13:19.872748	S23	6.432712431209637	3.364031577560098	3
2026-05-19 14:13:19.872748	S23	6.427307649732441	3.3560023969929773	4
2026-05-19 14:13:19.872748	S23	6.421668691643724	3.34351702750196	5
2026-05-19 14:13:19.872748	S23	6.415300762093608	3.332047375595039	6
2026-05-19 14:13:19.872748	S23	6.411937238826582	3.322766033210854	7
2026-05-19 14:13:19.872748	S23	6.412898148707953	3.3108862458908845	8
2026-05-19 14:13:19.872748	S23	6.412074511777661	3.2965199914567336	9
2026-05-19 14:13:19.872748	S23	6.4098095033605915	3.2878864250901643	10
2026-05-19 14:13:19.872748	S23	6.412928809536382	3.2774091342538725	11
2026-05-19 14:13:19.872748	S23	6.40894013382588	3.2600161077751295	12
2026-05-19 14:13:19.872748	S23	6.415920295839442	3.239278268511356	13
2026-05-19 14:13:19.872748	S23	6.416474272856746	3.2364909245251	14
2026-05-19 14:13:19.872748	S23	6.4068349868475565	3.2248955735389586	15
2026-05-19 14:13:19.872748	S23	6.415282882787636	3.212431456861708	16
2026-05-19 14:13:19.872748	S23	6.41715319472722	3.2096083056566727	17
2026-05-19 14:13:19.872748	S23	6.413506080085881	3.2027386377234848	18
2026-05-19 14:13:19.872748	S23	6.406385326689687	3.1969247797368325	19
2026-05-19 14:13:19.872748	S23	6.406370834829403	3.1927892848335375	20
2026-05-19 14:13:19.872748	S23	6.414671233491397	3.182655829518694	21
2026-05-19 14:13:19.872748	S23	6.415404145990848	3.180783427910768	22
2026-05-19 14:13:19.872748	S23	6.4137477917416135	3.1780839323155874	23
2026-05-19 14:13:19.872748	S23	6.404555715225349	3.1702735633413397	24
2026-05-19 14:13:19.872748	S23	6.404478480466949	3.1677704051578246	25
2026-05-19 14:13:19.872748	S23	6.404708487126733	3.163464748949636	26
2026-05-19 14:13:19.872748	S23	6.40634836208082	3.160930706968486	27
2026-05-19 14:13:19.872748	S23	6.410166267725845	3.1573542891098327	28
2026-05-19 14:13:19.872748	S23	6.411569592687037	3.154639201909589	29
2026-05-19 14:13:19.872748	S23	6.4112970213573135	3.149724427434961	30
2026-05-19 14:13:19.872748	S23	6.409483013244284	3.139061306109273	31
2026-05-19 14:13:19.872748	S23	6.410190245955306	3.130660301548353	32
2026-05-19 14:13:19.872748	S23	6.41162973089277	3.1251120325574817	33
2026-05-19 14:13:19.872748	S23	6.413035681940478	3.119125407791607	34
2026-05-19 14:13:19.872748	S23	6.413189184351381	3.1150295004572115	35
2026-05-19 14:13:19.872748	S23	6.412222241016522	3.113012352764983	36
2026-05-19 14:13:19.872748	S23	6.409258032144649	3.1091695310535954	37
2026-05-19 14:13:19.872748	S23	6.405799469157287	3.1022408977017335	38
2026-05-19 14:13:19.872748	S23	6.4048874650817	3.093548911789185	39
2026-05-19 14:13:19.872748	S23	6.406112177388152	3.091661082930443	40
2026-05-19 14:13:19.872748	S23	6.407959414947513	3.0856100442273657	41
2026-05-19 14:13:19.872748	S23	6.4089056361960814	3.07658157375468	42
2026-05-19 14:13:19.872748	S23	6.408327948861256	3.0668579539077427	43
2026-05-19 14:13:19.872748	S23	6.410027939953899	3.0547241640876805	44
2026-05-19 14:13:19.872748	S23	6.413283872788767	3.051287639531651	45
2026-05-19 14:13:19.872748	S23	6.412643244111905	3.0475735827799895	46
2026-05-19 14:13:19.872748	S23	6.41016288155775	3.044190793766038	47
2026-05-19 14:13:19.872748	S23	6.407101902312656	3.037302317397497	48
2026-05-19 14:13:19.872748	S23	6.406689475261931	3.033068624681434	49
2026-05-19 14:13:19.872748	S23	6.403735655766759	3.0240169580231395	50
2026-05-19 14:13:19.872748	S23	6.405088176897035	3.0169128954505453	51
2026-05-19 14:13:19.872748	S23	6.409440637381451	3.0108800151251387	52
2026-05-19 14:13:19.872748	S23	6.410380763096654	3.0087447173133626	53
2026-05-19 14:13:19.872748	S23	6.4045516795446815	2.9858130946558106	54
2026-05-19 14:13:19.872748	S23	6.407772986662284	2.9654342532945606	55
2026-05-19 14:13:19.872748	S23	6.407296624563649	2.9581862139644954	56
2026-05-19 14:13:19.872748	S23	6.40640501603815	2.9537150567586252	57
2026-05-19 14:13:19.872748	S23	6.40173157790376	2.9445104830466278	58
2026-05-19 14:13:19.872748	S23	6.401009077874495	2.9392026841148393	59
2026-05-19 14:13:19.872748	S23	6.402667749957708	2.9352381602582085	60
2026-05-19 14:13:19.872748	S23	6.4056243045465635	2.9268008462989314	61
2026-05-19 14:13:19.872748	S23	6.406759750106101	2.9218927107811314	62
2026-05-19 14:13:19.872748	S23	6.406417307994381	2.9180680333889946	63
2026-05-19 14:13:19.872748	S23	6.405857833522376	2.911443517759757	64
2026-05-19 14:13:19.872748	S23	6.404797450243564	2.899349438886773	65
2026-05-19 14:13:19.872748	S23	6.40604891645404	2.8831690465842996	66
2026-05-19 14:13:19.872748	S23	6.411608209262527	2.8753722227112277	67
2026-05-19 14:13:19.872748	S23	6.414190307628903	2.8726652616008295	68
2026-05-19 14:13:19.872748	S23	6.415124932065034	2.871221344301631	69
2026-05-19 14:13:19.872748	S23	6.419570726467086	2.8607514390517395	70
2026-05-19 14:13:19.872748	S24	6.439064428506866	3.359173482534807	1
2026-05-19 14:13:19.872748	S24	6.437676478675207	3.3604843286442487	2
2026-05-19 14:13:19.872748	S24	6.436363080765332	3.3616008244369153	3
2026-05-19 14:13:19.872748	S24	6.4348346448196665	3.3629146276216098	4
2026-05-19 14:13:19.872748	S24	6.4336224415737755	3.3639865701318974	5
2026-05-19 14:13:19.872748	S24	6.43254241779938	3.3652027572085723	6
2026-05-19 14:13:19.872748	S24	6.432138780507608	3.3661366040292973	7
2026-05-19 14:13:19.872748	S24	6.4316036908284895	3.367443002471636	8
2026-05-19 14:13:19.872748	S24	6.431311352388942	3.3685678157163617	9
2026-05-19 14:13:19.872748	S24	6.431330360461018	3.370501864170248	10
2026-05-19 14:13:19.872748	S24	6.433680608105894	3.3756960431041736	11
2026-05-19 14:13:19.872748	S24	6.435655420531615	3.380714620817125	12
2026-05-19 14:13:19.872748	S24	6.431705742505199	3.394534485200914	13
2026-05-19 14:13:19.872748	S24	6.430774164722624	3.3988433286005932	14
2026-05-19 14:13:19.872748	S24	6.424306607089957	3.4005809330729564	15
2026-05-19 14:13:19.872748	S24	6.41386250983842	3.399242340065401	16
2026-05-19 14:13:19.872748	S24	6.4062663023015425	3.398571008204439	17
2026-05-19 14:13:19.872748	S24	6.399206848658832	3.397843106168742	18
2026-05-19 14:13:19.872748	S24	6.398910689629854	3.397508311664364	19
2026-05-19 14:13:19.872748	S24	6.3993744044393805	3.3972196072351206	20
2026-05-19 14:13:19.872748	S24	6.401045927170438	3.396623767474978	21
2026-05-19 14:13:19.872748	S25	6.4379208	3.3358558	1
2026-05-19 14:13:19.872748	S25	6.436848659134332	3.3337635067404	2
2026-05-19 14:13:19.872748	S25	6.436326902187787	3.332813163730622	3
2026-05-19 14:13:19.872748	S25	6.435711974357931	3.332160967547441	4
2026-05-19 14:13:19.872748	S25	6.433122031204133	3.331938911398069	5
2026-05-19 14:13:19.872748	S25	6.427478038731522	3.3345191161320713	6
2026-05-19 14:13:19.872748	S27	6.427831511626604	3.258695694086362	1
2026-05-19 14:13:19.872748	S27	6.424669519971173	3.257496058473913	2
2026-05-19 14:13:19.872748	S28	6.427839632790165	3.258683952703204	1
2026-05-19 14:13:19.872748	S28	6.425672630901779	3.26227376609746	2
2026-05-19 14:13:19.872748	S29	6.427831	3.258691	1
2026-05-19 14:13:19.872748	S29	6.424950503	3.255345985	2
2026-05-19 14:13:19.872748	S30	6.427831	3.258691	1
2026-05-19 14:13:19.872748	S30	6.426316216996483	3.256180561773192	2
2026-05-19 14:13:19.872748	S30	6.4254521667465525	3.244916217511559	3
2026-05-19 14:13:19.872748	S30	6.424929976349759	3.2446885046995533	4
2026-05-19 14:13:19.872748	S30	6.421048503700959	3.244688504698047	5
2026-05-19 14:13:19.872748	S30	6.4186744457267935	3.2450101061180305	6
2026-05-19 14:13:19.872748	S30	6.415649600606585	3.2476171365445623	7
2026-05-19 14:13:19.872748	S30	6.41258796883281	3.250474116753253	8
2026-05-19 14:13:19.872748	S30	6.41143004192692	3.252033208416293	9
2026-05-19 14:13:19.872748	S30	6.410994586931963	3.2535695441037262	10
2026-05-19 14:13:19.872748	S30	6.411162252361791	3.254787460435665	11
2026-05-19 14:13:19.872748	S30	6.411405073247323	3.255507704262243	12
2026-05-19 14:13:19.872748	S30	6.411298075	3.255760155	13
2026-05-19 14:13:19.872748	S31	6.437032706359787	3.2366882862075954	1
2026-05-19 14:13:19.872748	S31	6.436659686731147	3.237013139521764	2
2026-05-19 14:13:19.872748	S31	6.435906473184218	3.2367604758327673	3
2026-05-19 14:13:19.872748	S31	6.435827565034586	3.2355188142795157	4
2026-05-19 14:13:19.872748	S31	6.435008258699341	3.2231960052289708	5
2026-05-19 14:13:19.872748	S31	6.435786131806296	3.2202350943124003	6
2026-05-19 14:13:19.872748	S31	6.434787933210316	3.2119264807787644	7
2026-05-19 14:13:19.872748	S31	6.434049058566856	3.2049925419524357	8
2026-05-19 14:13:19.872748	S31	6.436926785837613	3.1954311562160456	9
2026-05-19 14:13:19.872748	S31	6.434947718655792	3.1906752210310856	10
2026-05-19 14:13:19.872748	S31	6.43396918433745	3.1877237020120077	11
2026-05-19 14:13:19.872748	S31	6.4343811799226245	3.1857625422948956	12
2026-05-19 14:13:19.872748	S31	6.440922491787404	3.172814379152584	13
2026-05-19 14:13:19.872748	S31	6.441059699815696	3.1718879909015527	14
2026-05-19 14:13:19.872748	S31	6.440722921980239	3.168497193776517	15
2026-05-19 14:13:19.872748	S31	6.43937089308001	3.1666972698841107	16
2026-05-19 14:13:19.872748	S31	6.436824625190535	3.1648382086676676	17
2026-05-19 14:13:19.872748	S31	6.429187503424707	3.161836453275967	18
2026-05-19 14:13:19.872748	S31	6.426932673646462	3.1600978989181385	19
2026-05-19 14:13:19.872748	S31	6.4259456158371435	3.1586113207117954	20
2026-05-19 14:13:19.872748	S31	6.424909478383157	3.1565925521847973	21
2026-05-19 14:13:19.872748	S31	6.423564014223388	3.1533249745152006	22
2026-05-19 14:13:19.872748	S31	6.420643801466525	3.1498148610949954	23
2026-05-19 14:13:19.872748	S31	6.420098612322228	3.1475422416041	24
2026-05-19 14:13:19.872748	S31	6.4208403321568	3.1450922922475684	25
2026-05-19 14:13:19.872748	S31	6.424687866591572	3.1407618250371208	26
2026-05-19 14:13:19.872748	S31	6.427602395471645	3.134529883675164	27
2026-05-19 14:13:19.872748	S31	6.427057841494346	3.129958457773469	28
2026-05-19 14:13:19.872748	S31	6.426202276930269	3.1215463691570733	29
2026-05-19 14:13:19.872748	S31	6.426445591289685	3.1173592548107365	30
2026-05-19 14:13:19.872748	S31	6.427193955588322	3.1134385424061293	31
2026-05-19 14:13:19.872748	S31	6.4271092045492395	3.11247066413182	32
2026-05-19 14:13:19.872748	S31	6.426056602193725	3.1108654872016217	33
2026-05-19 14:13:19.872748	S31	6.424795722881342	3.1095816758923434	34
2026-05-19 14:13:19.872748	S31	6.420125314249134	3.108430360115875	35
2026-05-19 14:13:19.872748	S31	6.4099434577192795	3.1071958360029726	36
2026-05-19 14:13:19.872748	S31	6.406541926021504	3.1017012428889785	37
2026-05-19 14:13:19.872748	S31	6.405899897386547	3.0940712349018042	38
2026-05-19 14:13:19.872748	S31	6.408024456020577	3.0879373911034804	39
2026-05-19 14:13:19.872748	S31	6.409428723210496	3.0803848621850136	40
2026-05-19 14:13:19.872748	S31	6.409157429009731	3.067382292065332	41
2026-05-19 14:13:19.872748	S31	6.411235006526496	3.0553030692394145	42
2026-05-19 14:13:19.872748	S31	6.41436413729285	3.0514181097843505	43
2026-05-19 14:13:19.872748	S31	6.413171078238083	3.04715562186459	44
2026-05-19 14:13:19.872748	S31	6.408138332027285	3.0367520394909775	45
2026-05-19 14:13:19.872748	S31	6.407688324838816	3.033458840511173	46
2026-05-19 14:13:19.872748	S31	6.4048227127176744	3.0239755648669018	47
2026-05-19 14:13:19.872748	S31	6.406118978207598	3.0174651456543273	48
2026-05-19 14:13:19.872748	S31	6.410894259306353	3.0107257351382657	49
2026-05-19 14:13:19.872748	S31	6.411072125168388	3.007650860630008	50
2026-05-19 14:13:19.872748	S31	6.405470693744675	2.9856695834037055	51
2026-05-19 14:13:19.872748	S31	6.408508470288993	2.9655299163031827	52
2026-05-19 14:13:19.872748	S31	6.4079569444932645	2.956804842891785	53
2026-05-19 14:13:19.872748	S31	6.407195735225407	2.952088522144134	54
2026-05-19 14:13:19.872748	S31	6.4028389806283315	2.9444484882434594	55
2026-05-19 14:13:19.872748	S31	6.402122746019401	2.939102057758177	56
2026-05-19 14:13:19.872748	S31	6.406154887666581	2.927908612903771	57
2026-05-19 14:13:19.872748	S31	6.407437959156809	2.921619115583468	58
2026-05-19 14:13:19.872748	S31	6.406047300447803	2.899082387079744	59
2026-05-19 14:13:19.872748	S31	6.406999993296523	2.886241764882726	60
2026-05-19 14:13:19.872748	S31	6.407635753692297	2.8837333802198373	61
2026-05-19 14:13:19.872748	S31	6.4126754474357455	2.877330767381494	62
2026-05-19 14:13:19.872748	S31	6.423728682512854	2.853766457099823	63
2026-05-19 14:13:19.872748	S31	6.439214375655684	2.82979728795101	64
2026-05-19 14:13:19.872748	S31	6.449805710705228	2.8181839980296104	65
2026-05-19 14:13:19.872748	S31	6.453752160714842	2.8082646348645994	66
2026-05-19 14:13:19.872748	S31	6.45489247936348	2.8017794380355383	67
2026-05-19 14:13:19.872748	S31	6.454240534916114	2.7973627155243435	68
2026-05-19 14:13:19.872748	S31	6.45313640536623	2.7946337956620653	69
2026-05-19 14:13:19.872748	S31	6.451039537485315	2.789672080548087	70
2026-05-19 14:13:19.872748	S31	6.447231703428869	2.7834625052832394	71
2026-05-19 14:13:19.872748	S31	6.442231262864453	2.7499947244342877	72
2026-05-19 14:13:19.872748	S31	6.444896655896192	2.741883110826464	73
2026-05-19 14:13:19.872748	S31	6.449392556218395	2.737241965915075	74
2026-05-19 14:13:19.872748	S31	6.455418453924203	2.727767185694944	75
2026-05-19 14:13:19.872748	S31	6.455146886523394	2.720738670560678	76
2026-05-19 14:13:19.872748	S31	6.454705989543719	2.717846716450481	77
2026-05-19 14:13:19.872748	S31	6.451848500099782	2.7128513646557053	78
2026-05-19 14:13:19.872748	S31	6.450507217702025	2.710784442127874	79
2026-05-19 14:13:19.872748	S31	6.448790031018845	2.707951256864135	80
2026-05-19 14:13:19.872748	S31	6.447199637576162	2.706833480025807	81
2026-05-19 14:13:19.872748	S31	6.446902057934679	2.706590685374948	82
2026-05-19 14:13:19.872748	S31	6.446770144319249	2.7065624188267066	83
2026-05-19 14:13:19.872748	S31	6.44659510783716	2.7066075285560345	84
2026-05-19 14:13:19.872748	S31	6.446423534176169	2.7066718051391945	85
2026-05-19 14:13:19.872748	S31	6.445980017715854	2.7068056736123083	86
2026-05-19 14:13:19.872748	S31	6.44511667669255	2.706980451691635	87
2026-05-19 14:13:19.872748	S31	6.444996737571515	2.7071356508463253	88
2026-05-19 14:13:19.872748	S31	6.44491126989962	2.7074420023072605	89
2026-05-19 14:13:19.872748	S31	6.4447103596807835	2.7079612373287887	90
2026-05-19 14:13:19.872748	S31	6.444807736152157	2.707477970726316	91
2026-05-19 14:13:19.872748	S31	6.444836317785175	2.7072623969492398	92
2026-05-19 14:13:19.872748	S31	6.4449304717613245	2.7069111907947736	93
2026-05-19 14:13:19.872748	S31	6.445035585469597	2.706791602787007	94
2026-05-19 14:13:19.872748	S31	6.4463457628936	2.706600978755745	95
2026-05-19 14:13:19.872748	S31	6.447923309026791	2.7057937731751736	96
2026-05-19 14:13:19.872748	S31	6.448045575381251	2.7053895989484236	97
2026-05-19 14:13:19.872748	S31	6.446995303254283	2.7031113029712124	98
2026-05-19 14:13:19.872748	S31	6.443521821288755	2.691101335658608	99
2026-05-19 14:13:19.872748	S31	6.440990640306751	2.6724553846552936	100
2026-05-19 14:13:19.872748	S31	6.443938334717046	2.663273550831292	101
2026-05-19 14:13:19.872748	S31	6.456218156714357	2.6448414901198873	102
2026-05-19 14:13:19.872748	S31	6.4615666821603455	2.628462522406565	103
2026-05-19 14:13:19.872748	S31	6.4619795658877734	2.627454906162825	104
2026-05-19 14:13:19.872748	S31	6.465995687572757	2.62338128823194	105
2026-05-19 14:13:19.872748	S33	6.437043497	3.23667811	1
2026-05-19 14:13:19.872748	S33	6.428563414	3.235353134	2
2026-05-19 14:13:19.872748	S34	6.5523891	3.4728735	1
2026-05-19 14:13:19.872748	S34	6.529079908099284	3.4610299356086838	2
2026-05-19 14:13:19.872748	S34	6.46521670519526	3.465871070608161	3
2026-05-19 14:13:19.872748	S34	6.462789111884183	3.465643966936233	4
2026-05-19 14:13:19.872748	S34	6.45911838994063	3.465565866469349	5
2026-05-19 14:13:19.872748	S34	6.457243978735411	3.465643966936233	6
2026-05-19 14:13:19.872748	S34	6.455369567530192	3.46595636880377	7
2026-05-19 14:13:19.872748	S34	6.45380755819251	3.466385921371633	8
2026-05-19 14:13:19.872748	S34	6.45134739348566	3.467205976273916	9
2026-05-19 14:13:19.872748	S34	6.450605439050261	3.466815473939495	10
2026-05-19 14:13:19.872748	S34	6.450175886482398	3.465604916702791	11
2026-05-19 14:13:19.872748	S34	6.449590132980767	3.464042907365109	12
2026-05-19 14:13:19.872748	S34	6.449642259223669	3.462591518804611	13
2026-05-19 14:13:19.872748	S34	6.44979406377354	3.460181621575412	14
2026-05-19 14:13:19.872748	S34	6.450666939935297	3.457790699914948	15
2026-05-19 14:13:19.872748	S34	6.451179280291111	3.456158801003837	16
2026-05-19 14:13:19.872748	S34	6.451198255859845	3.455134120292209	17
2026-05-19 14:13:19.872748	S34	6.451179280291111	3.454375097542855	18
2026-05-19 14:13:19.872748	S34	6.450970549035039	3.453445294674897	19
2026-05-19 14:13:19.872748	S34	6.450116648442015	3.45223085827593	20
2026-05-19 14:13:19.872748	S34	6.448921187611783	3.452098029294794	21
2026-05-19 14:13:19.872748	S34	6.448124213724961	3.451965200313657	22
2026-05-19 14:13:19.872748	S34	6.446738997207391	3.45207905372606	23
2026-05-19 14:13:19.872748	S34	6.445239927277417	3.452154956000995	24
2026-05-19 14:13:19.872748	S34	6.443207039208269	3.45232855932938	25
2026-05-19 14:13:19.872748	S34	6.442498475147751	3.452282096112297	26
2026-05-19 14:13:19.872748	S34	6.441197505069424	3.451910390375632	27
2026-05-19 14:13:19.872748	S34	6.440543330834378	3.4515448463044276	28
2026-05-19 14:13:19.872748	S34	6.4388087451329525	3.4488281618000247	29
2026-05-19 14:13:19.872748	S34	6.437874451455791	3.4452292417895647	30
2026-05-19 14:13:19.872748	S34	6.437977948470125	3.443264661528905	31
2026-05-19 14:13:19.872748	S34	6.44027662977546	3.4399056894551125	32
2026-05-19 14:13:19.872748	S34	6.441539322400302	3.437120765738393	33
2026-05-19 14:13:19.872748	S34	6.442092949832996	3.4357087691201538	34
2026-05-19 14:13:19.872748	S34	6.441964180897786	3.4303510832949207	35
2026-05-19 14:13:19.872748	S34	6.442096	3.427176	36
2026-05-19 14:13:19.872748	S36	6.552351446907041	3.472861666725476	1
2026-05-19 14:13:19.872748	S36	6.523250980436249	3.4432387976488785	2
2026-05-19 14:13:19.872748	S36	6.487805305761261	3.403010921729284	3
2026-05-19 14:13:19.872748	S36	6.468693684643348	3.3882024169275686	4
2026-05-19 14:13:19.872748	S36	6.465593168746079	3.3825059373731294	5
2026-05-19 14:13:19.872748	S36	6.459907635493732	3.375944956456408	6
2026-05-19 14:13:19.872748	S36	6.452492879800741	3.3759327676650726	7
2026-05-19 14:13:19.872748	S36	6.444304244072807	3.3883839533469873	8
2026-05-19 14:13:19.872748	S36	6.438292209535858	3.3967311670392935	9
2026-05-19 14:13:19.872748	S36	6.437413284784931	3.396562509929246	10
2026-05-19 14:13:19.872748	S36	6.43280505454388	3.394305476693841	11
2026-05-19 14:13:19.872748	S36	6.433418707041351	3.391842635473581	12
2026-05-19 14:13:19.872748	S36	6.436742379532573	3.380843541115392	13
2026-05-19 14:13:19.872748	S36	6.435131128881921	3.377129518807548	14
2026-05-19 14:13:19.872748	S36	6.432226300375852	3.368167138550125	15
2026-05-19 14:13:19.872748	S36	6.433595286054489	3.3641792601216762	16
2026-05-19 14:13:19.872748	S36	6.4390625163644755	3.359173996142955	17
2026-05-19 14:13:19.872748	S37	6.5393273	3.5010197	1
2026-05-19 14:13:19.872748	S37	6.494954741487431	3.469001122090702	2
2026-05-19 14:13:19.872748	S37	6.463647151729197	3.467065044572604	3
2026-05-19 14:13:19.872748	S37	6.459470394839868	3.4662791651411577	4
2026-05-19 14:13:19.872748	S37	6.4546456409649755	3.4652317777494788	5
2026-05-19 14:13:19.872748	S37	6.449433932047	3.46443340969953	6
2026-05-19 14:13:19.872748	S37	6.4476939455620865	3.4593630870596055	7
2026-05-19 14:13:19.872748	S37	6.450532963838811	3.456081288236424	8
2026-05-19 14:13:19.872748	S37	6.449602521368319	3.4531054383026816	9
2026-05-19 14:13:19.872748	S37	6.445931285475844	3.4530229308051226	10
2026-05-19 14:13:19.872748	S37	6.43982062893625	3.4530177232723966	11
2026-05-19 14:13:19.872748	S37	6.4372769536334555	3.4495654834068366	12
2026-05-19 14:13:19.872748	S37	6.437007940602944	3.446401390629092	13
2026-05-19 14:13:19.872748	S37	6.436763794695786	3.4437314780300596	14
2026-05-19 14:13:19.872748	S37	6.436702570425009	3.4419820549383355	15
2026-05-19 14:13:19.872748	S37	6.438725436792637	3.440239412233823	16
2026-05-19 14:13:19.872748	S37	6.441564971412435	3.4359241080804366	17
2026-05-19 14:13:19.872748	S37	6.441672118818423	3.435682742401845	18
2026-05-19 14:13:19.872748	S37	6.441774659038057	3.4296723803534577	19
2026-05-19 14:13:19.872748	S37	6.442095174	3.427179994	20
2026-05-19 14:13:19.872748	S38	6.5632172	3.5890471	1
2026-05-19 14:13:19.872748	S38	6.5151518	3.6054649	2
2026-05-19 14:13:19.872748	S40	6.5632172	3.5890471	1
2026-05-19 14:13:19.872748	S40	6.537141320555509	3.5672873342029794	2
2026-05-19 14:13:19.872748	S40	6.520392307813857	3.5349949452306118	3
2026-05-19 14:13:19.872748	S40	6.491688510058024	3.473219400397198	4
2026-05-19 14:13:19.872748	S40	6.463292185930974	3.467837774009678	5
2026-05-19 14:13:19.872748	S40	6.456723430979685	3.4662568017525204	6
2026-05-19 14:13:19.872748	S40	6.449433932047	3.46443340969953	7
2026-05-19 14:13:19.872748	S40	6.450532963838811	3.456081288236424	8
2026-05-19 14:13:19.872748	S40	6.449602521368319	3.4531054383026816	9
2026-05-19 14:13:19.872748	S40	6.445931285475844	3.4530229308051226	10
2026-05-19 14:13:19.872748	S40	6.44002484997792	3.4526005934890387	11
2026-05-19 14:13:19.872748	S40	6.437612058325149	3.449404646300565	12
2026-05-19 14:13:19.872748	S40	6.4369732684380025	3.4437232518822896	13
2026-05-19 14:13:19.872748	S40	6.436702737006566	3.4419823902133824	14
2026-05-19 14:13:19.872748	S40	6.438656367751662	3.4401946909370205	15
2026-05-19 14:13:19.872748	S40	6.44149739560917	3.4358887664506965	16
2026-05-19 14:13:19.872748	S40	6.441585138063656	3.4356654057995546	17
2026-05-19 14:13:19.872748	S40	6.4417107081843845	3.4296605416577735	18
2026-05-19 14:13:19.872748	S40	6.442095174	3.427179994	19
2026-05-19 14:13:19.872748	S41	6.4906336	3.5790217	1
2026-05-19 14:13:19.872748	S41	6.522970642064163	3.56216718694834	2
2026-05-19 14:13:19.872748	S41	6.536139	3.553069	3
2026-05-19 14:13:19.872748	S43	6.563707	3.20189717	1
2026-05-19 14:13:19.872748	S43	6.563754161317007	3.200954686933727	2
2026-05-19 14:13:19.872748	S43	6.563954657910514	3.2001329932358544	3
2026-05-19 14:13:19.872748	S43	6.5638400884380275	3.199820653526473	4
2026-05-19 14:13:19.872748	S43	6.563482058668228	3.1992824681807406	5
2026-05-19 14:13:19.872748	S43	6.563343620421037	3.199080648675988	6
2026-05-19 14:13:19.872748	S43	6.563267240682748	3.198869218718329	7
2026-05-19 14:13:19.872748	S43	6.563190860931485	3.1988355821339667	8
2026-05-19 14:13:19.872748	S43	6.56314312358144	3.198648178307792	9
2026-05-19 14:13:19.872748	S43	6.562808962003331	3.1983694751827443	10
2026-05-19 14:13:19.872748	S43	6.562775545832906	3.1981772661307843	11
2026-05-19 14:13:19.872748	S43	6.56268484478781	3.1979225891359704	12
2026-05-19 14:13:19.872748	S43	6.562585440369432	3.1977315005038633	13
2026-05-19 14:13:19.872748	S43	6.562529606935243	3.1975558702352487	14
2026-05-19 14:13:19.872748	S43	6.562383044141967	3.197246760962713	15
2026-05-19 14:13:19.872748	S43	6.562281845998356	3.197014929007622	16
2026-05-19 14:13:19.872748	S43	6.56216668946368	3.196484525595878	17
2026-05-19 14:13:19.872748	S43	6.5620550224960965	3.1960770633722007	18
2026-05-19 14:13:19.872748	S43	6.561944	3.195462	19
2026-05-19 14:13:19.872748	S44	6.552217147901231	3.206458960639196	1
2026-05-19 14:13:19.872748	S44	6.552213098433981	3.2062347756607608	2
2026-05-19 14:13:19.872748	S44	6.552124010159659	3.206059503767648	3
2026-05-19 14:13:19.872748	S44	6.55193368515684	3.2056029816294824	4
2026-05-19 14:13:19.872748	S44	6.551524688629527	3.204852980973868	5
2026-05-19 14:13:19.872748	S44	6.551459897068909	3.2047388504396395	6
2026-05-19 14:13:19.872748	S44	6.551427501286014	3.2045105893699883	7
2026-05-19 14:13:19.872748	S44	6.551322214976821	3.203654610360246	8
2026-05-19 14:13:19.872748	S44	6.5513262644502674	3.2034548819255804	9
2026-05-19 14:13:19.872748	S44	6.551743360082554	3.2032877622137335	10
2026-05-19 14:13:19.872748	S44	6.552484412625574	3.2032429252184613	11
2026-05-19 14:13:19.872748	S44	6.552889358907208	3.2033896644772994	12
2026-05-19 14:13:19.872748	S44	6.553261909194447	3.2033652079346098	13
2026-05-19 14:13:19.872748	S44	6.553440085320744	3.2030146641494923	14
2026-05-19 14:13:19.872748	S44	6.553619978736052	3.2027401962956787	15
2026-05-19 14:13:19.872748	S44	6.553702106376321	3.2022080220690157	16
2026-05-19 14:13:19.872748	S44	6.553619978736052	3.201732681983799	17
2026-05-19 14:13:19.872748	S44	6.553619978736052	3.201407177360693	18
2026-05-19 14:13:19.872748	S44	6.553738037213179	3.2011075064365	19
2026-05-19 14:13:19.872748	S44	6.553804765906563	3.200689000492673	20
2026-05-19 14:13:19.872748	S44	6.553491654272349	3.2001516595265684	21
2026-05-19 14:13:19.872748	S44	6.553186138152498	3.1996021235747776	22
2026-05-19 14:13:19.872748	S44	6.553092886862487	3.199435727309236	23
2026-05-19 14:13:19.872748	S44	6.552800416795847	3.199273597615388	24
2026-05-19 14:13:19.872748	S44	6.552618152753212	3.1990560024988497	25
2026-05-19 14:13:19.872748	S44	6.5523765468276025	3.1983477517289884	26
2026-05-19 14:13:19.872748	S45	6.453045	3.2055781	1
2026-05-19 14:13:19.872748	S45	6.44924766057521	3.199973014889986	2
2026-05-19 14:13:19.872748	S45	6.447892503582012	3.198820781828631	3
2026-05-19 14:13:19.872748	S45	6.448318189940002	3.1980634475332828	4
2026-05-19 14:13:19.872748	S45	6.448439002217537	3.1973605843238517	5
2026-05-19 14:13:19.872748	S45	6.447878552738921	3.1962278873935293	6
2026-05-19 14:13:19.872748	S45	6.448222289093553	3.1958022825542045	7
2026-05-19 14:13:19.872748	S45	6.449184158390468	3.1951582827146994	8
2026-05-19 14:13:19.872748	S45	6.448945328381154	3.190336296168261	9
2026-05-19 14:13:19.872748	S45	6.44717478507785	3.190108700740698	10
2026-05-19 14:13:19.872748	S45	6.446701250902201	3.1894842344428587	11
2026-05-19 14:13:19.872748	S45	6.447117308478079	3.187172055340014	12
2026-05-19 14:13:19.872748	S45	6.446716905894055	3.1851638105138953	13
2026-05-19 14:13:19.872748	S45	6.446088650056611	3.183852294551066	14
2026-05-19 14:13:19.872748	S45	6.44519076395503	3.1830716415167197	15
2026-05-19 14:13:19.872748	S45	6.444336695895039	3.182925981877554	16
2026-05-19 14:13:19.872748	S45	6.443421282404239	3.1834482185225856	17
2026-05-19 14:13:19.872748	S45	6.442325322166363	3.184842050434117	18
2026-05-19 14:13:19.872748	S45	6.441369153736541	3.1861565081729357	19
2026-05-19 14:13:19.872748	S45	6.440710095755794	3.1871462640571235	20
2026-05-19 14:13:19.872748	S45	6.440570304172597	3.1875592529854098	21
2026-05-19 14:13:19.872748	S45	6.438215365861761	3.1841892312428204	22
2026-05-19 14:13:19.872748	S45	6.43822412959572	3.183755188123402	23
2026-05-19 14:13:19.872748	S45	6.438670437092647	3.183026503788277	24
2026-05-19 14:13:19.872748	S45	6.438836305288792	3.1818744905242347	25
2026-05-19 14:13:19.872748	S45	6.438831478652006	3.178630233545138	26
2026-05-19 14:13:19.872748	S45	6.440570977419682	3.175295272479863	27
2026-05-19 14:13:19.872748	S45	6.44177124325536	3.1729130744724126	28
2026-05-19 14:13:19.872748	S45	6.441646712033163	3.168680870735124	29
2026-05-19 14:13:19.872748	S45	6.4401788901745	3.166052483140002	30
2026-05-19 14:13:19.872748	S45	6.437949834786924	3.164220303646933	31
2026-05-19 14:13:19.872748	S45	6.434237890209866	3.163159957467908	32
2026-05-19 14:13:19.872748	S45	6.429883301776516	3.1616330957430177	33
2026-05-19 14:13:19.872748	S45	6.4275837988729005	3.159569164854714	34
2026-05-19 14:13:19.872748	S45	6.425308209577167	3.155662917584274	35
2026-05-19 14:13:19.872748	S45	6.424888976278016	3.1543194472877625	36
2026-05-19 14:13:19.872748	S45	6.424452718031615	3.153021847003207	37
2026-05-19 14:13:19.872748	S45	6.424470195400829	3.1529759503605135	38
2026-05-19 14:13:19.872748	S46	6.453045	3.2055781	1
2026-05-19 14:13:19.872748	S46	6.4439992753856155	3.2133758708961153	2
2026-05-19 14:13:19.872748	S46	6.436897635382269	3.220108632495032	3
2026-05-19 14:13:19.872748	S46	6.432677843061942	3.2294659393105793	4
2026-05-19 14:13:19.872748	S46	6.429666280469933	3.2353004716561915	5
2026-05-19 14:13:19.872748	S46	6.428457394968772	3.2388192004819505	6
2026-05-19 14:13:19.872748	S46	6.426160799892964	3.2426417185899803	7
2026-05-19 14:13:19.872748	S46	6.422754876026199	3.2435887762655544	8
2026-05-19 14:13:19.872748	S46	6.420804812931879	3.243480210162973	9
2026-05-19 14:13:19.872748	S46	6.419185098401302	3.2431011881352956	10
2026-05-19 14:13:19.872748	S46	6.418033063984844	3.2431638017557427	11
2026-05-19 14:13:19.872748	S46	6.417171543081243	3.243134865272293	12
2026-05-19 14:13:19.872748	S46	6.416903162902312	3.242400989331251	13
2026-05-19 14:13:19.872748	S46	6.417336462	3.236747347	14
2026-05-19 14:13:19.872748	S47	6.453045	3.2055781	1
2026-05-19 14:13:19.872748	S47	6.443705417783854	3.213537175940317	2
2026-05-19 14:13:19.872748	S47	6.436563701627779	3.220390916321497	3
2026-05-19 14:13:19.872748	S47	6.43247337383163	3.229715351005915	4
2026-05-19 14:13:19.872748	S47	6.4295562149907415	3.2353591104455037	5
2026-05-19 14:13:19.872748	S47	6.427887642619536	3.2398290907464204	6
2026-05-19 14:13:19.872748	S47	6.426219070248331	3.242765511589867	7
2026-05-19 14:13:19.872748	S47	6.422761350553254	3.243562714581501	8
2026-05-19 14:13:19.872748	S47	6.420675321871601	3.2435062718470267	9
2026-05-19 14:13:19.872748	S47	6.419052933711599	3.24319428707592	10
2026-05-19 14:13:19.872748	S47	6.418006630991536	3.243296800242576	11
2026-05-19 14:13:19.872748	S47	6.417197976115749	3.2432279642128887	12
2026-05-19 14:13:19.872748	S47	6.416903162902312	3.242400989331251	13
2026-05-19 14:13:19.872748	S47	6.416023554348714	3.236195917891799	14
2026-05-19 14:13:19.872748	S47	6.4099872073989745	3.2296750489391384	15
2026-05-19 14:13:19.872748	S47	6.407790168124701	3.226439799544212	16
2026-05-19 14:13:19.872748	S47	6.406926003137938	3.22075870239245	17
2026-05-19 14:13:19.872748	S47	6.408723075349343	3.212589230878601	18
2026-05-19 14:13:19.872748	S47	6.40667	3.2055711	19
2026-05-19 14:13:19.872748	S48	6.453045	3.2055781	1
2026-05-19 14:13:19.872748	S48	6.447753733168739	3.206507009062568	2
2026-05-19 14:13:19.872748	S48	6.44759333037889	3.206549468624587	3
2026-05-19 14:13:19.872748	S48	6.4474895403384	3.206606081373945	4
2026-05-19 14:13:19.872748	S48	6.447263089340966	3.206757048705567	5
2026-05-19 14:13:19.872748	S48	6.446852646908118	3.207063701097925	6
2026-05-19 14:13:19.872748	S48	6.446753574596741	3.207120313847283	7
2026-05-19 14:13:19.872748	S48	6.446512970411968	3.207162773409302	8
2026-05-19 14:13:19.872748	S48	6.445913818814591	3.207077854285265	9
2026-05-19 14:13:19.872748	S48	6.445319384946329	3.206922169224529	10
2026-05-19 14:13:19.872748	S48	6.444715659936991	3.206880303143875	11
2026-05-19 14:13:19.872748	S48	6.444024095685053	3.206716143952759	12
2026-05-19 14:13:19.872748	S48	6.44379357426774	3.206611361490344	13
2026-05-19 14:13:19.872748	S48	6.443496690624233	3.206992071103785	14
2026-05-19 14:13:19.872748	S48	6.443206792478219	3.207093360817452	15
2026-05-19 14:13:19.872748	S48	6.442976271060906	3.207110824561188	16
2026-05-19 14:13:19.872748	S48	6.442218344582773	3.207093360817452	17
2026-05-19 14:13:19.872748	S48	6.441972286081016	3.207087422275739	18
2026-05-19 14:13:19.872748	S48	6.441838523361273	3.207058059727502	19
2026-05-19 14:13:19.872748	S48	6.441918250835998	3.206675938787262	20
2026-05-19 14:13:19.872748	S48	6.442209225532754	3.206243656827114	21
2026-05-19 14:13:19.872748	S48	6.442215138823721	3.206215925531559	22
2026-05-19 14:13:19.872748	S48	6.442375001586341	3.205791799834811	23
2026-05-19 14:13:19.872748	S48	6.442355426554183	3.20531873655767	24
2026-05-19 14:13:19.872748	S48	6.442244501371957	3.205077311161059	25
2026-05-19 14:13:19.872748	S48	6.442150338416655	3.20493034267917	26
2026-05-19 14:13:19.872748	S48	6.441704438429321	3.204285751505772	27
2026-05-19 14:13:19.872748	S48	6.441401780924966	3.203959990375129	28
2026-05-19 14:13:19.872748	S48	6.441354418491078	3.203785557996665	29
2026-05-19 14:13:19.872748	S48	6.441242737999472	3.203564692343531	30
2026-05-19 14:13:19.872748	S48	6.441170960117492	3.203400667163599	31
2026-05-19 14:13:19.872748	S48	6.440800074521579	3.203338883817041	32
2026-05-19 14:13:19.872748	S48	6.440642681173014	3.203299037399683	33
2026-05-19 14:13:19.872748	S48	6.440407587310599	3.203243252415381	34
2026-05-19 14:13:19.872748	S48	6.440385671781051	3.203245244736249	35
2026-05-19 14:13:19.872748	S48	6.440301994304598	3.203257198661456	36
2026-05-19 14:13:19.872748	S48	6.440246209320297	3.203249229377985	37
2026-05-19 14:13:19.872748	S48	6.440220309149014	3.203251221698853	38
2026-05-19 14:13:19.872748	S48	6.440041000270901	3.203267160265796	39
2026-05-19 14:13:19.872748	S48	6.440001551200425	3.203241930853736	40
2026-05-19 14:13:19.872748	S48	6.439760168342391	3.202966336252044	41
2026-05-19 14:13:19.872748	S48	6.439528288746485	3.202766767747371	42
2026-05-19 14:13:19.872748	S48	6.439502191847852	3.202753876768035	43
2026-05-19 14:13:19.872748	S48	6.439092172085316	3.202203687836461	44
2026-05-19 14:13:19.872748	S48	6.438640208900688	3.202045470151907	45
2026-05-19 14:13:19.872748	S48	6.438633081454093	3.202045470151907	46
2026-05-19 14:13:19.872748	S48	6.438625478844391	3.202045945315013	47
2026-05-19 14:13:19.872748	S48	6.438616925908477	3.202047845967439	48
2026-05-19 14:13:19.872748	S48	6.438311661017526	3.202071022216864	49
2026-05-19 14:13:19.872748	S48	6.438183603169832	3.202078203030754	50
2026-05-19 14:13:19.872748	S48	6.437937061892962	3.202035118147418	51
2026-05-19 14:13:19.872748	S48	6.437876024974902	3.202027937333528	52
2026-05-19 14:13:19.872748	S48	6.437765919161931	3.20200878849649	53
2026-05-19 14:13:19.872748	S48	6.437441994377468	3.20082636677412	54
2026-05-19 14:13:19.872748	S48	6.43715923571036	3.199756112006094	55
2026-05-19 14:13:19.872748	S48	6.436902903086906	3.199639837414012	56
2026-05-19 14:13:19.872748	S48	6.436702065155129	3.199552631469951	57
2026-05-19 14:13:19.872748	S48	6.436384278990706	3.1995313545348125	58
2026-05-19 14:13:19.872748	S48	6.435921149579246	3.199567656320274	59
2026-05-19 14:13:19.872748	S48	6.435623156949082	3.199646934451239	60
2026-05-19 14:13:19.872748	S48	6.433292234701217	3.2001354082008246	61
2026-05-19 14:13:19.872748	S48	6.432759232131751	3.199922214137146	62
2026-05-19 14:13:19.872748	S48	6.4322429170687325	3.1996089844113307	63
2026-05-19 14:13:19.872748	S48	6.430450701985262	3.1996085041686833	64
2026-05-19 14:13:19.872748	S48	6.429165693153001	3.1997482387104133	65
2026-05-19 14:13:19.872748	S48	6.427028671131331	3.1998551860050477	66
2026-05-19 14:13:19.872748	S48	6.424659668944023	3.1994435354969037	67
2026-05-19 14:13:19.872748	S48	6.421904736017284	3.1991685369020644	68
2026-05-19 14:13:19.872748	S48	6.418771317346787	3.198991802989313	69
2026-05-19 14:13:19.872748	S48	6.417086779951141	3.199705611290856	70
2026-05-19 14:13:19.872748	S48	6.416089523093111	3.2002584058357857	71
2026-05-19 14:13:19.872748	S48	6.415119224661087	3.20121531573126	72
2026-05-19 14:13:19.872748	S48	6.413333736751193	3.2018701422779334	73
2026-05-19 14:13:19.872748	S48	6.410165812732754	3.1999147121518763	74
2026-05-19 14:13:19.872748	S48	6.4081782047899924	3.1972785701516298	75
2026-05-19 14:13:19.872748	S48	6.407547361436321	3.1941694526290196	76
2026-05-19 14:13:19.872748	S48	6.408677677505447	3.1915368136561915	77
2026-05-19 14:13:19.872748	S48	6.415385859614633	3.1829462734779224	78
2026-05-19 14:13:19.872748	S48	6.416144272746559	3.1813587271909425	79
2026-05-19 14:13:19.872748	S179	6.5810406	3.4077602	7
2026-05-19 14:13:19.872748	S48	6.4147366868836935	3.176731213515937	80
2026-05-19 14:13:19.872748	S48	6.412147555168023	3.175259524468374	81
2026-05-19 14:13:19.872748	S48	6.405512854020799	3.1701586529056414	82
2026-05-19 14:13:19.872748	S48	6.403919063	3.164768668	83
2026-05-19 14:13:19.872748	S49	6.453045	3.2055781	1
2026-05-19 14:13:19.872748	S49	6.452859406910235	3.2055503302167665	2
2026-05-19 14:13:19.872748	S49	6.4488477620229645	3.2085599588723426	3
2026-05-19 14:13:19.872748	S49	6.441771013024649	3.214914351434288	4
2026-05-19 14:13:19.872748	S49	6.438241088231592	3.2183566989445467	5
2026-05-19 14:13:19.872748	S49	6.436670404135796	3.2195216493488203	6
2026-05-19 14:13:19.872748	S49	6.430447548195033	3.234999185863245	7
2026-05-19 14:13:19.872748	S49	6.426307013354048	3.2438312022125615	8
2026-05-19 14:13:19.872748	S49	6.426404669666653	3.2590812364505837	9
2026-05-19 14:13:19.872748	S49	6.428652344339639	3.280714036242955	10
2026-05-19 14:13:19.872748	S49	6.430686729604574	3.2913610283814023	11
2026-05-19 14:13:19.872748	S49	6.43665738404745	3.2973840808382704	12
2026-05-19 14:13:19.872748	S49	6.437912934627278	3.3050338469901703	13
2026-05-19 14:13:19.872748	S49	6.4354963873772135	3.3114494968423003	14
2026-05-19 14:13:19.872748	S49	6.432080226223633	3.31791719609825	15
2026-05-19 14:13:19.872748	S49	6.431339452040831	3.320369787434771	16
2026-05-19 14:13:19.872748	S49	6.435761473222598	3.329808869330492	17
2026-05-19 14:13:19.872748	S49	6.437662539885238	3.3359172043088847	18
2026-05-19 14:13:19.872748	S49	6.437550906958947	3.33939850971376	19
2026-05-19 14:13:19.872748	S49	6.436438754191585	3.343574899360192	20
2026-05-19 14:13:19.872748	S49	6.435937632109329	3.3462507467164073	21
2026-05-19 14:13:19.872748	S49	6.4358585051234485	3.3478441839150435	22
2026-05-19 14:13:19.872748	S49	6.4371395894709025	3.351206863309187	23
2026-05-19 14:13:19.872748	S49	6.43877206935116	3.3554565723224528	24
2026-05-19 14:13:19.872748	S49	6.439064160007163	3.359172844741863	25
2026-05-19 14:13:19.872748	S49	6.431222724284254	3.3655859540163817	26
2026-05-19 14:13:19.872748	S49	6.429962674273867	3.3680240441413503	27
2026-05-19 14:13:19.872748	S49	6.434235720152785	3.3787626168140434	28
2026-05-19 14:13:19.872748	S49	6.434907570793428	3.380996244598805	29
2026-05-19 14:13:19.872748	S49	6.434684601322047	3.383067385642164	30
2026-05-19 14:13:19.872748	S49	6.431804239191692	3.392446385790919	31
2026-05-19 14:13:19.872748	S49	6.43125700997129	3.3946036835186533	32
2026-05-19 14:13:19.872748	S49	6.432816023428927	3.39742618013031	33
2026-05-19 14:13:19.872748	S49	6.4387120670337765	3.3987593326409353	34
2026-05-19 14:13:19.872748	S49	6.4492081354225945	3.389713112398539	35
2026-05-19 14:13:19.872748	S50	6.582567357189847	3.4076028852038247	1
2026-05-19 14:13:19.872748	S50	6.582420173741085	3.4082012334543985	2
2026-05-19 14:13:19.872748	S53	6.449378262193392	3.1439026468631823	1
2026-05-19 14:13:19.872748	S53	6.449265497044593	3.145117585903165	2
2026-05-19 14:13:19.872748	S54	6.510683889386883	3.1734943722962328	1
2026-05-19 14:13:19.872748	S54	6.511395593906656	3.1736089675958397	2
2026-05-19 14:13:19.872748	S54	6.51223326638268	3.173427594649553	3
2026-05-19 14:13:19.872748	S54	6.51282389610077	3.1727851181964297	4
2026-05-19 14:13:19.872748	S54	6.5127828485961174	3.1722341504553384	5
2026-05-19 14:13:19.872748	S54	6.5128353189245445	3.1717475842150122	6
2026-05-19 14:13:19.872748	S54	6.514279431457879	3.170502605137642	7
2026-05-19 14:13:19.872748	S63	6.4390640082534985	3.359172912897035	1
2026-05-19 14:13:19.872748	S63	6.432563835800667	3.364272597850107	2
2026-05-19 14:13:19.872748	S63	6.427659970091112	3.359255410786096	3
2026-05-19 14:13:19.872748	S64	6.439064357935185	3.3591741891575486	1
2026-05-19 14:13:19.872748	S64	6.432960952557403	3.363295408042652	2
2026-05-19 14:13:19.872748	S64	6.426457420245349	3.353693965264206	3
2026-05-19 14:13:19.872748	S64	6.422165642999366	3.3493181804324705	4
2026-05-19 14:13:19.872748	S64	6.423413222263939	3.3491200504610363	5
2026-05-19 14:13:19.872748	S64	6.426358133440893	3.347764109790347	6
2026-05-19 14:13:19.872748	S65	6.453176022	3.204245481	1
2026-05-19 14:13:19.872748	S65	6.451306611466339	3.204691272048581	2
2026-05-19 14:13:19.872748	S65	6.447691481869566	3.206286535856859	3
2026-05-19 14:13:19.872748	S65	6.446734703680288	3.207021241535907	4
2026-05-19 14:13:19.872748	S65	6.446451639933496	3.207058983368812	5
2026-05-19 14:13:19.872748	S65	6.446220471206949	3.207073136556152	6
2026-05-19 14:13:19.872748	S65	6.446017608855081	3.20701180607768	7
2026-05-19 14:13:19.872748	S65	6.445489223194404	3.206874991933397	8
2026-05-19 14:13:19.872748	S65	6.445215594905838	3.206851403287831	9
2026-05-19 14:13:19.872748	S65	6.444706080161613	3.206804225996699	10
2026-05-19 14:13:19.872748	S65	6.444432747288471	3.206754564188978	11
2026-05-19 14:13:19.872748	S65	6.444041559428788	3.206611361490344	12
2026-05-19 14:13:19.872748	S65	6.443884385735166	3.206527535520412	13
2026-05-19 14:13:19.872748	S65	6.443779603272752	3.206503086279182	14
2026-05-19 14:13:19.872748	S65	6.443469776041071	3.206911246986321	15
2026-05-19 14:13:19.872748	S65	6.443091325419357	3.207035222189985	16
2026-05-19 14:13:19.872748	S65	6.442796068684314	3.207031959684626	17
2026-05-19 14:13:19.872748	S65	6.442169667655271	3.207031959684626	18
2026-05-19 14:13:19.872748	S65	6.442053848715006	3.207009122147109	19
2026-05-19 14:13:19.872748	S65	6.441954138394951	3.206969564269626	20
2026-05-19 14:13:19.872748	S65	6.441885829688987	3.206950397050636	21
2026-05-19 14:13:19.872748	S65	6.441900522322349	3.206819560367967	22
2026-05-19 14:13:19.872748	S65	6.44193717899138	3.206682097859101	23
2026-05-19 14:13:19.872748	S65	6.442025765941538	3.206556854239912	24
2026-05-19 14:13:19.872748	S65	6.442205994564274	3.206275819777342	25
2026-05-19 14:13:19.872748	S65	6.44230374568169	3.206031441983802	26
2026-05-19 14:13:19.872748	S65	6.442395387354266	3.205793173635101	27
2026-05-19 14:13:19.872748	S65	6.442386223187009	3.205686258350428	28
2026-05-19 14:13:19.872748	S65	6.442374004297332	3.205310527492861	29
2026-05-19 14:13:19.872748	S65	6.442248760678145	3.205050876087226	30
2026-05-19 14:13:19.872748	S65	6.442053258443313	3.204772896347075	31
2026-05-19 14:13:19.872748	S65	6.441714184254777	3.204284140759996	32
2026-05-19 14:13:19.872748	S65	6.441414821457691	3.203948121293879	33
2026-05-19 14:13:19.872748	S65	6.441369527365509	3.203789150136757	34
2026-05-19 14:13:19.872748	S65	6.441268060756738	3.203600712149039	35
2026-05-19 14:13:19.872748	S65	6.441178615486484	3.203392676480475	36
2026-05-19 14:13:19.872748	S65	6.441130799785653	3.203386699517871	37
2026-05-19 14:13:19.872748	S65	6.440997314287503	3.203358807025721	38
2026-05-19 14:13:19.872748	S65	6.440841913259805	3.203332906854437	39
2026-05-19 14:13:19.872748	S65	6.440680535269504	3.203299037399683	40
2026-05-19 14:13:19.872748	S65	6.440503218712259	3.203251221698853	41
2026-05-19 14:13:19.872748	S65	6.440395633385391	3.203231298490174	42
2026-05-19 14:13:19.872748	S65	6.440290040379391	3.203245244736249	43
2026-05-19 14:13:19.872748	S65	6.440241033406033	3.203238129548885	44
2026-05-19 14:13:19.872748	S65	6.440090881864421	3.203245732158587	45
2026-05-19 14:13:19.872748	S65	6.440049067511061	3.203253334768289	46
2026-05-19 14:13:19.872748	S65	6.440017658768764	3.203237227199949	47
2026-05-19 14:13:19.872748	S65	6.439907346520113	3.203113913993497	48
2026-05-19 14:13:19.872748	S65	6.439859522026505	3.203059773057337	49
2026-05-19 14:13:19.872748	S65	6.439782976171497	3.202975839514171	50
2026-05-19 14:13:19.872748	S65	6.439673585476046	3.202875950657815	51
2026-05-19 14:13:19.872748	S65	6.43958688975491	3.202806617388411	52
2026-05-19 14:13:19.872748	S65	6.439535973431276	3.202761060677791	53
2026-05-19 14:13:19.872748	S65	6.439503815753192	3.202744981838749	54
2026-05-19 14:13:19.872748	S65	6.439444860010037	3.202661907837032	55
2026-05-19 14:13:19.872748	S65	6.439329628330236	3.202503799253118	56
2026-05-19 14:13:19.872748	S65	6.439096485164126	3.202198301311318	57
2026-05-19 14:13:19.872748	S65	6.438649159270327	3.202039905356677	58
2026-05-19 14:13:19.872748	S65	6.438634797642549	3.202036314949733	59
2026-05-19 14:13:19.872748	S65	6.438582941520941	3.202044064682965	60
2026-05-19 14:13:19.872748	S65	6.438353316713476	3.202058903121032	61
2026-05-19 14:13:19.872748	S65	6.438179991338727	3.202069670598982	62
2026-05-19 14:13:19.872748	S65	6.437928089527067	3.202024113888362	63
2026-05-19 14:13:19.872748	S65	6.437775849379801	3.202000121152798	64
2026-05-19 14:13:19.872748	S65	6.437750730276349	3.201913346068144	65
2026-05-19 14:13:19.872748	S65	6.437481633442951	3.200908287509451	66
2026-05-19 14:13:19.872748	S65	6.437172448732188	3.199729685962439	67
2026-05-19 14:13:19.872748	S65	6.436724445702199	3.199509817228341	68
2026-05-19 14:13:19.872748	S65	6.436292210738742	3.199493808525991	69
2026-05-19 14:13:19.872748	S65	6.435795940965884	3.199541834633042	70
2026-05-19 14:13:19.872748	S65	6.435235636383625	3.199637886847143	71
2026-05-19 14:13:19.872748	S65	6.434339149052009	3.199862008680047	72
2026-05-19 14:13:19.872748	S65	6.433438748806801	3.1997841869184964	73
2026-05-19 14:13:19.872748	S65	6.43273181328109	3.199359806428408	74
2026-05-19 14:13:19.872748	S65	6.431818591734833	3.199198168707534	75
2026-05-19 14:13:19.872748	S65	6.430644201964959	3.199255843590292	76
2026-05-19 14:13:19.872748	S65	6.426958699751105	3.1994380185557665	77
2026-05-19 14:13:19.872748	S65	6.425125650963817	3.199341777141711	78
2026-05-19 14:13:19.872748	S65	6.421862519723986	3.1989498692047227	79
2026-05-19 14:13:19.872748	S65	6.419539060415695	3.1993084065809607	80
2026-05-19 14:13:19.872748	S65	6.4185382067447	3.198753850037465	81
2026-05-19 14:13:19.872748	S65	6.417367093332628	3.1990057328668655	82
2026-05-19 14:13:19.872748	S65	6.416346762494447	3.199419475461721	83
2026-05-19 14:13:19.872748	S65	6.415971707178945	3.2074984715131776	84
2026-05-19 14:13:19.872748	S65	6.415927806687773	3.210824404637061	85
2026-05-19 14:13:19.872748	S65	6.414245767461447	3.212965728872917	86
2026-05-19 14:13:19.872748	S65	6.407223917048471	3.2237268041425375	87
2026-05-19 14:13:19.872748	S65	6.417414091167817	3.2365837449062225	88
2026-05-19 14:13:19.872748	S65	6.417350288914502	3.2372597763751965	89
2026-05-19 14:13:19.872748	S65	6.417642526504029	3.2381149502855386	90
2026-05-19 14:13:19.872748	S65	6.406081707185514	3.2236778972348654	91
2026-05-19 14:13:19.872748	S65	6.407635772661759	3.216529244086983	92
2026-05-19 14:13:19.872748	S65	6.408039987408987	3.2152718637634554	93
2026-05-19 14:13:19.872748	S65	6.4083549122800285	3.211038542705512	94
2026-05-19 14:13:19.872748	S65	6.40667	3.2055711	95
2026-05-19 14:13:19.872748	S66	6.419640776	3.19931338	1
2026-05-19 14:13:19.872748	S66	6.421984536069804	3.199145397220724	2
2026-05-19 14:13:19.872748	S66	6.424433993276074	3.1994061425901195	3
2026-05-19 14:13:19.872748	S66	6.426186215415105	3.1996964344306136	4
2026-05-19 14:13:19.872748	S66	6.427118715176602	3.199831389667562	5
2026-05-19 14:13:19.872748	S66	6.428989972296103	3.19972491649118	6
2026-05-19 14:13:19.872748	S66	6.430107030285126	3.1996258983773553	7
2026-05-19 14:13:19.872748	S66	6.431773806246719	3.199568934256252	8
2026-05-19 14:13:19.872748	S66	6.432273968057532	3.1995899612521272	9
2026-05-19 14:13:19.872748	S66	6.432792902819451	3.1998971470515216	10
2026-05-19 14:13:19.872748	S66	6.43328055951541	3.200119527116382	11
2026-05-19 14:13:19.872748	S66	6.43436575253427	3.1999301450223365	12
2026-05-19 14:13:19.872748	S66	6.435899236061808	3.1995728505905525	13
2026-05-19 14:13:19.872748	S66	6.436116945457069	3.1995528247939005	14
2026-05-19 14:13:19.872748	S66	6.436394448350841	3.19953270233641	15
2026-05-19 14:13:19.872748	S66	6.436714755539769	3.199539515110127	16
2026-05-19 14:13:19.872748	S66	6.436916116108734	3.1996372914716216	17
2026-05-19 14:13:19.872748	S66	6.437164520919091	3.199753767484294	18
2026-05-19 14:13:19.872748	S66	6.437473705629854	3.200908287509451	19
2026-05-19 14:13:19.872748	S66	6.437725611172897	3.201841414090075	20
2026-05-19 14:13:19.872748	S66	6.437763289828076	3.201979569159064	21
2026-05-19 14:13:19.872748	S66	6.437771282270083	3.202003546485087	22
2026-05-19 14:13:19.872748	S66	6.437815811589839	3.202013822481954	23
2026-05-19 14:13:19.872748	S66	6.437908338637405	3.202025543728899	24
2026-05-19 14:13:19.872748	S66	6.437989758975746	3.202040231978898	25
2026-05-19 14:13:19.872748	S66	6.438177619158258	3.202073415821495	26
2026-05-19 14:13:19.872748	S66	6.43839969429971	3.202061147197785	27
2026-05-19 14:13:19.872748	S66	6.438603747714049	3.202046015263568	28
2026-05-19 14:13:19.872748	S66	6.438630405648967	3.202041463908826	29
2026-05-19 14:13:19.872748	S66	6.43863735792205	3.20204119368395	30
2026-05-19 14:13:19.872748	S66	6.438659930491162	3.202048529448984	31
2026-05-19 14:13:19.872748	S66	6.438914849384235	3.202137092820286	32
2026-05-19 14:13:19.872748	S66	6.439094667522329	3.20220137017026	33
2026-05-19 14:13:19.872748	S66	6.439220687091494	3.202367316731634	34
2026-05-19 14:13:19.872748	S66	6.439372908749296	3.2025694471297	35
2026-05-19 14:13:19.872748	S66	6.439503580264954	3.202749661875542	36
2026-05-19 14:13:19.872748	S66	6.439528288746485	3.20276296644252	37
2026-05-19 14:13:19.872748	S66	6.439668937025969	3.202877005588047	38
2026-05-19 14:13:19.872748	S66	6.439777274214221	3.202975839514171	39
2026-05-19 14:13:19.872748	S66	6.440011054462552	3.203241930853736	40
2026-05-19 14:13:19.872748	S66	6.440041464901359	3.20325713607314	41
2026-05-19 14:13:19.872748	S66	6.440088815971731	3.203257198661456	42
2026-05-19 14:13:19.872748	S66	6.440246209320297	3.203243252415381	43
2026-05-19 14:13:19.872748	S66	6.440298009662863	3.203251221698853	44
2026-05-19 14:13:19.872748	S66	6.440395633385391	3.203237275452777	45
2026-05-19 14:13:19.872748	S66	6.440515172637467	3.203259190982324	46
2026-05-19 14:13:19.872748	S66	6.440640688852145	3.203295052757947	47
2026-05-19 14:13:19.872748	S66	6.440889728960635	3.203348845421381	48
2026-05-19 14:13:19.872748	S66	6.440989345004031	3.203362791667456	49
2026-05-19 14:13:19.872748	S66	6.441176553108988	3.203398271258415	50
2026-05-19 14:13:19.872748	S66	6.441240055540959	3.20355221137117	51
2026-05-19 14:13:19.872748	S66	6.441317070340274	3.203706798222758	52
2026-05-19 14:13:19.872748	S66	6.441362891176562	3.203786221005659	53
2026-05-19 14:13:19.872748	S66	6.44140871201285	3.203957285461136	54
2026-05-19 14:13:19.872748	S66	6.441488134795751	3.204039762966456	55
2026-05-19 14:13:19.872748	S66	6.441677527585744	3.204253593535803	56
2026-05-19 14:13:19.872748	S66	6.441708074809936	3.204284140759995	57
2026-05-19 14:13:19.872748	S66	6.442215158731531	3.205017274140613	58
2026-05-19 14:13:19.872748	S66	6.442245705955723	3.205060040254483	59
2026-05-19 14:13:19.872748	S66	6.442361951564902	3.20531221154695	60
2026-05-19 14:13:19.872748	S66	6.44238478910242	3.205798324845531	61
2026-05-19 14:13:19.872748	S66	6.442213711477624	3.206247327145644	62
2026-05-19 14:13:19.872748	S66	6.442074851093258	3.206470400949608	63
2026-05-19 14:13:19.872748	S66	6.441928038352076	3.206679201292622	64
2026-05-19 14:13:19.872748	S66	6.441890899387729	3.206836643784536	65
2026-05-19 14:13:19.872748	S66	6.441871148414869	3.206992809620311	66
2026-05-19 14:13:19.872748	S66	6.441926611005981	3.207012384652468	67
2026-05-19 14:13:19.872748	S66	6.442316141547694	3.207075897073717	68
2026-05-19 14:13:19.872748	S66	6.442645993437772	3.207071109748941	69
2026-05-19 14:13:19.872748	S66	6.443213777975713	3.207054940581234	70
2026-05-19 14:13:19.872748	S66	6.443489705126738	3.206943172621324	71
2026-05-19 14:13:19.872748	S66	6.443741183036533	3.206621839736585	72
2026-05-19 14:13:19.872748	S66	6.44379357426774	3.206558970259136	73
2026-05-19 14:13:19.872748	S66	6.444010124690065	3.206649781726563	74
2026-05-19 14:13:19.872748	S66	6.444331457574803	3.206754564188978	75
2026-05-19 14:13:19.872748	S66	6.444673746952025	3.206831404661415	76
2026-05-19 14:13:19.872748	S66	6.445361844508347	3.20689386284985	77
2026-05-19 14:13:19.872748	S66	6.445777004670308	3.207007088348567	78
2026-05-19 14:13:19.872748	S66	6.446196882561384	3.207082572014378	79
2026-05-19 14:13:19.872748	S66	6.446588454077779	3.20711559611817	80
2026-05-19 14:13:19.872748	S66	6.44676772778408	3.207073136556152	81
2026-05-19 14:13:19.872748	S66	6.447220629778947	3.206728742330888	82
2026-05-19 14:13:19.872748	S66	6.44746123396372	3.206549468624587	83
2026-05-19 14:13:19.872748	S66	6.447677510874578	3.206454187796723	84
2026-05-19 14:13:19.872748	S66	6.449548102136533	3.205581656519368	85
2026-05-19 14:13:19.872748	S66	6.451273222048684	3.204891608554508	86
2026-05-19 14:13:19.872748	S66	6.453176022	3.204245481	87
2026-05-19 14:13:19.872748	S67	6.417628639562252	3.23811341801126	1
2026-05-19 14:13:19.872748	S67	6.409757517783558	3.2272602090868565	2
2026-05-19 14:13:19.872748	S67	6.4085397038415515	3.2254231155984794	3
2026-05-19 14:13:19.872748	S67	6.4081659868844305	3.2232686200206953	4
2026-05-19 14:13:19.872748	S67	6.409586273475355	3.2207713459128495	5
2026-05-19 14:13:19.872748	S67	6.413005876008016	3.2154762968180055	6
2026-05-19 14:13:19.872748	S67	6.416532338938524	3.212122823311799	7
2026-05-19 14:13:19.872748	S67	6.417091732596178	3.2094630115870144	8
2026-05-19 14:13:19.872748	S67	6.416312939988156	3.204770157372055	9
2026-05-19 14:13:19.872748	S67	6.4166571718915435	3.201827439011633	10
2026-05-19 14:13:19.872748	S67	6.417426555989133	3.2003417588756733	11
2026-05-19 14:13:19.872748	S67	6.418975395484804	3.1991616114517223	12
2026-05-19 14:13:19.872748	S67	6.419394438591079	3.1991658082454473	13
2026-05-19 14:13:19.872748	S67	6.419549122371283	3.199313162298789	14
2026-05-19 14:13:19.872748	S67	6.420974206348441	3.19940813382868	15
2026-05-19 14:13:19.872748	S67	6.422546056697114	3.1994976382440266	16
2026-05-19 14:13:19.872748	S67	6.42477571842149	3.1996237557023495	17
2026-05-19 14:13:19.872748	S67	6.427003026230518	3.2000000798854784	18
2026-05-19 14:13:19.872748	S67	6.431425628865944	3.1997046139062406	19
2026-05-19 14:13:19.872748	S67	6.432159589725955	3.1997381846599064	20
2026-05-19 14:13:19.872748	S67	6.432735366258572	3.200062631566629	21
2026-05-19 14:13:19.872748	S67	6.433160709837133	3.200267303534137	22
2026-05-19 14:13:19.872748	S67	6.434231285584525	3.200053897429205	23
2026-05-19 14:13:19.872748	S67	6.435940995097866	3.19962926699655	24
2026-05-19 14:13:19.872748	S67	6.436461588157869	3.199563201887413	25
2026-05-19 14:13:19.872748	S67	6.436696779946398	3.19957112970051	26
2026-05-19 14:13:19.872748	S67	6.436900260482541	3.199655693040205	27
2026-05-19 14:13:19.872748	S67	6.437151307897263	3.199771967632287	28
2026-05-19 14:13:19.872748	S67	6.437410283125082	3.200752373851886	29
2026-05-19 14:13:19.872748	S67	6.437758738348042	3.20200878849649	30
2026-05-19 14:13:19.872748	S67	6.437769509568876	3.202018362915009	31
2026-05-19 14:13:19.872748	S67	6.438193177588351	3.202082990240014	32
2026-05-19 14:13:19.872748	S67	6.438619776887115	3.202050221782971	33
2026-05-19 14:13:19.872748	S67	6.438627379496817	3.202049271456758	34
2026-05-19 14:13:19.872748	S67	6.438631655964774	3.202049271456758	35
2026-05-19 14:13:19.872748	S67	6.438640208900688	3.202050221782971	36
2026-05-19 14:13:19.872748	S67	6.43883740158983	3.202118645270287	37
2026-05-19 14:13:19.872748	S67	6.439091138688628	3.202205600118752	38
2026-05-19 14:13:19.872748	S67	6.439497680103172	3.202754779116971	39
2026-05-19 14:13:19.872748	S67	6.439521141175508	3.202767412002075	40
2026-05-19 14:13:19.872748	S67	6.439760263643545	3.202972245210545	41
2026-05-19 14:13:19.872748	S67	6.439994874366905	3.203241145193472	42
2026-05-19 14:13:19.872748	S67	6.440031038666562	3.203267160265796	43
2026-05-19 14:13:19.872748	S67	6.440044984912637	3.203277121870136	44
2026-05-19 14:13:19.872748	S67	6.440242224678562	3.203259190982324	45
2026-05-19 14:13:19.872748	S67	6.440286055737656	3.20326317562406	46
2026-05-19 14:13:19.872748	S67	6.440407587310599	3.203249229377985	47
2026-05-19 14:13:19.872748	S67	6.440823982371993	3.203350837742249	48
2026-05-19 14:13:19.872748	S67	6.44116843429947	3.203405503344249	49
2026-05-19 14:13:19.872748	S67	6.441274710980389	3.203641160332373	50
2026-05-19 14:13:19.872748	S67	6.441349388418964	3.203788335041375	51
2026-05-19 14:13:19.872748	S67	6.441399374070119	3.203967593928279	52
2026-05-19 14:13:19.872748	S67	6.441716179410287	3.204307767709364	53
2026-05-19 14:13:19.872748	S67	6.442062004978404	3.204816718545461	54
2026-05-19 14:13:19.872748	S67	6.442238180267823	3.205080981479588	55
2026-05-19 14:13:19.872748	S67	6.442349105450049	3.205328931886917	56
2026-05-19 14:13:19.872748	S67	6.442365417976847	3.205795470153339	57
2026-05-19 14:13:19.872748	S67	6.442202292708867	3.206229383366165	58
2026-05-19 14:13:19.872748	S67	6.442189242687428	3.206262008419761	59
2026-05-19 14:13:19.872748	S67	6.441924979753302	3.206646984052194	60
2026-05-19 14:13:19.872748	S67	6.441905404721144	3.206686134116508	61
2026-05-19 14:13:19.872748	S67	6.441786453757598	3.207284516819753	62
2026-05-19 14:13:19.872748	S67	6.441708545116405	3.207913350852247	63
2026-05-19 14:13:19.872748	S67	6.441502643707535	3.20858670410828	64
2026-05-19 14:13:19.872748	S67	6.441591682154614	3.20909311027604	65
2026-05-19 14:13:19.872748	S67	6.441352391328089	3.209593951540858	66
2026-05-19 14:13:19.872748	S67	6.441338479070733	3.209908368557105	67
2026-05-19 14:13:19.872748	S67	6.441191009142759	3.210222785573352	68
2026-05-19 14:13:19.872748	S67	6.441115882953037	3.210373037952797	69
2026-05-19 14:13:19.872748	S67	6.441129795210393	3.210612328779321	70
2026-05-19 14:13:19.872748	S67	6.441316219458963	3.210648500648447	71
2026-05-19 14:13:19.872748	S67	6.44146925428988	3.21067910761463	72
2026-05-19 14:13:19.872748	S67	6.441594464606085	3.210698584774929	73
2026-05-19 14:13:19.872748	S67	6.441647331184038	3.210851619605845	74
2026-05-19 14:13:19.872748	S67	6.441602811960498	3.211082563077956	75
2026-05-19 14:13:19.872748	S67	6.441694632859049	3.211268987326527	76
2026-05-19 14:13:19.872748	S67	6.441886622010562	3.211516625507465	77
2026-05-19 14:13:19.872748	S67	6.44192835878263	3.21157505698836	78
2026-05-19 14:13:19.872748	S67	6.441945053491457	3.211878344198722	79
2026-05-19 14:13:19.872748	S67	6.441936706137044	3.212039726384052	80
2026-05-19 14:13:19.872748	S67	6.441800366014954	3.212373620560597	81
2026-05-19 14:13:19.872748	S67	6.441552727834017	3.21263238854742	82
2026-05-19 14:13:19.872748	S67	6.441483166547236	3.212715862091557	83
2026-05-19 14:13:19.872748	S67	6.442439488371421	3.212697757950497	84
2026-05-19 14:13:19.872748	S67	6.451213609763073	3.205776272723006	85
2026-05-19 14:13:19.872748	S67	6.453176019638212	3.204245483565353	86
2026-05-19 14:13:19.872748	S68	6.417336462	3.236747347	1
2026-05-19 14:13:19.872748	S68	6.412269804000883	3.230747874272814	2
2026-05-19 14:13:19.872748	S68	6.40835632435245	3.225238583047931	3
2026-05-19 14:13:19.872748	S68	6.408135629318128	3.223126060666493	4
2026-05-19 14:13:19.872748	S68	6.409566035152125	3.220710249046361	5
2026-05-19 14:13:19.872748	S68	6.413594518274495	3.215032802303151	6
2026-05-19 14:13:19.872748	S68	6.416402673340301	3.211966283168974	7
2026-05-19 14:13:19.872748	S68	6.417041137533617	3.2089233226028524	8
2026-05-19 14:13:19.872748	S68	6.416292701932701	3.2049941792152783	9
2026-05-19 14:13:19.872748	S68	6.416626814828135	3.2016135999796616	10
2026-05-19 14:13:19.872748	S68	6.417568222034982	3.1998529839453553	11
2026-05-19 14:13:19.872748	S68	6.418975395484804	3.1991616114517223	12
2026-05-19 14:13:19.872748	S68	6.419394438591079	3.1991658082454473	13
2026-05-19 14:13:19.872748	S68	6.419549122371283	3.199313162298789	14
2026-05-19 14:13:19.872748	S68	6.421075395681876	3.1993674025848375	15
2026-05-19 14:13:19.872748	S68	6.422950812640763	3.1994467241888467	16
2026-05-19 14:13:19.872748	S68	6.42495785784266	3.1996543041362475	17
2026-05-19 14:13:19.872748	S68	6.42706373911336	3.199979714262889	18
2026-05-19 14:13:19.872748	S68	6.431567291018999	3.199684248283623	19
2026-05-19 14:13:19.872748	S68	6.432159589725955	3.1997381846599064	20
2026-05-19 14:13:19.872748	S68	6.432947858922435	3.2003070190311345	21
2026-05-19 14:13:19.872748	S68	6.433828543093221	3.200236755101518	22
2026-05-19 14:13:19.872748	S68	6.435071134597871	3.1999317036962562	23
2026-05-19 14:13:19.872748	S68	6.436072537363941	3.199649632619111	24
2026-05-19 14:13:19.872748	S68	6.436461588157869	3.199563201887413	25
2026-05-19 14:13:19.872748	S68	6.436696779946398	3.19957112970051	26
2026-05-19 14:13:19.872748	S68	6.436900260482541	3.199655693040205	27
2026-05-19 14:13:19.872748	S68	6.437151307897263	3.199771967632287	28
2026-05-19 14:13:19.872748	S68	6.437410283125082	3.200752373851886	29
2026-05-19 14:13:19.872748	S68	6.437758738348042	3.20200878849649	30
2026-05-19 14:13:19.872748	S68	6.437769509568876	3.202018362915009	31
2026-05-19 14:13:19.872748	S68	6.438193177588351	3.202082990240014	32
2026-05-19 14:13:19.872748	S68	6.438619776887115	3.202050221782971	33
2026-05-19 14:13:19.872748	S68	6.438627379496817	3.202049271456758	34
2026-05-19 14:13:19.872748	S68	6.438631655964774	3.202049271456758	35
2026-05-19 14:13:19.872748	S68	6.438640208900688	3.202050221782971	36
2026-05-19 14:13:19.872748	S68	6.43883740158983	3.202118645270287	37
2026-05-19 14:13:19.872748	S68	6.439091138688628	3.202205600118752	38
2026-05-19 14:13:19.872748	S68	6.439497680103172	3.202754779116971	39
2026-05-19 14:13:19.872748	S68	6.439521141175508	3.202767412002075	40
2026-05-19 14:13:19.872748	S68	6.439760263643545	3.202972245210545	41
2026-05-19 14:13:19.872748	S68	6.439994874366905	3.203241145193472	42
2026-05-19 14:13:19.872748	S68	6.440031038666562	3.203267160265796	43
2026-05-19 14:13:19.872748	S68	6.440044984912637	3.203277121870136	44
2026-05-19 14:13:19.872748	S68	6.440242224678562	3.203259190982324	45
2026-05-19 14:13:19.872748	S68	6.440286055737656	3.20326317562406	46
2026-05-19 14:13:19.872748	S68	6.440407587310599	3.203249229377985	47
2026-05-19 14:13:19.872748	S68	6.440823982371993	3.203350837742249	48
2026-05-19 14:13:19.872748	S68	6.44116843429947	3.203405503344249	49
2026-05-19 14:13:19.872748	S68	6.441274710980389	3.203641160332373	50
2026-05-19 14:13:19.872748	S68	6.441349388418964	3.203788335041375	51
2026-05-19 14:13:19.872748	S68	6.441399374070119	3.203967593928279	52
2026-05-19 14:13:19.872748	S68	6.441716179410287	3.204307767709364	53
2026-05-19 14:13:19.872748	S68	6.442062004978404	3.204816718545461	54
2026-05-19 14:13:19.872748	S68	6.442238180267823	3.205080981479588	55
2026-05-19 14:13:19.872748	S68	6.442349105450049	3.205328931886917	56
2026-05-19 14:13:19.872748	S68	6.442365417976847	3.205795470153339	57
2026-05-19 14:13:19.872748	S68	6.442202292708867	3.206229383366165	58
2026-05-19 14:13:19.872748	S68	6.442189242687428	3.206262008419761	59
2026-05-19 14:13:19.872748	S68	6.441924979753302	3.206646984052194	60
2026-05-19 14:13:19.872748	S68	6.441905404721144	3.206686134116508	61
2026-05-19 14:13:19.872748	S68	6.441786453757598	3.207284516819753	62
2026-05-19 14:13:19.872748	S68	6.441708545116405	3.207913350852247	63
2026-05-19 14:13:19.872748	S68	6.441502643707535	3.20858670410828	64
2026-05-19 14:13:19.872748	S68	6.441591682154614	3.20909311027604	65
2026-05-19 14:13:19.872748	S68	6.441352391328089	3.209593951540858	66
2026-05-19 14:13:19.872748	S68	6.441338479070733	3.209908368557105	67
2026-05-19 14:13:19.872748	S68	6.441191009142759	3.210222785573352	68
2026-05-19 14:13:19.872748	S68	6.441115882953037	3.210373037952797	69
2026-05-19 14:13:19.872748	S68	6.441129795210393	3.210612328779321	70
2026-05-19 14:13:19.872748	S68	6.441316219458963	3.210648500648447	71
2026-05-19 14:13:19.872748	S68	6.44146925428988	3.21067910761463	72
2026-05-19 14:13:19.872748	S68	6.441594464606085	3.210698584774929	73
2026-05-19 14:13:19.872748	S68	6.441647331184038	3.210851619605845	74
2026-05-19 14:13:19.872748	S68	6.441602811960498	3.211082563077956	75
2026-05-19 14:13:19.872748	S68	6.441694632859049	3.211268987326527	76
2026-05-19 14:13:19.872748	S68	6.441886622010562	3.211516625507465	77
2026-05-19 14:13:19.872748	S68	6.44192835878263	3.21157505698836	78
2026-05-19 14:13:19.872748	S68	6.441945053491457	3.211878344198722	79
2026-05-19 14:13:19.872748	S68	6.441936706137044	3.212039726384052	80
2026-05-19 14:13:19.872748	S68	6.441800366014954	3.212373620560597	81
2026-05-19 14:13:19.872748	S68	6.441552727834017	3.21263238854742	82
2026-05-19 14:13:19.872748	S68	6.441483166547236	3.212715862091557	83
2026-05-19 14:13:19.872748	S68	6.442439488371421	3.212697757950497	84
2026-05-19 14:13:19.872748	S68	6.451213609763073	3.205776272723006	85
2026-05-19 14:13:19.872748	S68	6.453176022	3.204245481	86
2026-05-19 14:13:19.872748	S71	6.407584812481417	3.2616159304640178	1
2026-05-19 14:13:19.872748	S71	6.40744777275269	3.2605470575297772	2
2026-05-19 14:13:19.872748	S71	6.411504310045416	3.2556342103025315	3
2026-05-19 14:13:19.872748	S71	6.411317163616957	3.255300614439932	4
2026-05-19 14:13:19.872748	S71	6.411349652567893	3.2542675023519223	5
2026-05-19 14:13:19.872748	S71	6.4119734400257755	3.2524660948806456	6
2026-05-19 14:13:19.872748	S71	6.409074449829603	3.243441896844587	7
2026-05-19 14:13:19.872748	S71	6.415678302516511	3.2476566930685635	8
2026-05-19 14:13:19.872748	S71	6.416809692198299	3.246097756810798	9
2026-05-19 14:13:19.872748	S71	6.418674789028032	3.245004902531207	10
2026-05-19 14:13:19.872748	S71	6.420823183239591	3.2446960524086137	11
2026-05-19 14:13:19.872748	S71	6.425214378369972	3.2447673255132656	12
2026-05-19 14:13:19.872748	S71	6.426174645711939	3.2503844843803904	13
2026-05-19 14:13:19.872748	S71	6.426214183394208	3.2522147173987435	14
2026-05-19 14:13:19.872748	S71	6.425053675366328	3.25535825779761	15
2026-05-19 14:13:19.872748	S71	6.4246903799026995	3.2575065080177126	16
2026-05-19 14:13:19.872748	S71	6.425798003775398	3.26224407925514	17
2026-05-19 14:13:19.872748	S71	6.427857404741758	3.2587013221436507	18
2026-05-19 14:13:19.872748	S72	6.436703143129123	3.441982008903595	1
2026-05-19 14:13:19.872748	S72	6.437046811544366	3.4436723731694787	2
2026-05-19 14:13:19.872748	S72	6.43776755553403	3.4493453782957766	3
2026-05-19 14:13:19.872748	S72	6.440125413678583	3.452445226354998	4
2026-05-19 14:13:19.872748	S72	6.4444242534317855	3.452895711656537	5
2026-05-19 14:13:19.872748	S72	6.449338650123927	3.452591394081874	6
2026-05-19 14:13:19.872748	S72	6.450261869593485	3.453365717067803	7
2026-05-19 14:13:19.872748	S72	6.450706711196459	3.454399833861562	8
2026-05-19 14:13:19.872748	S72	6.4508961182622	3.455547411968639	9
2026-05-19 14:13:19.872748	S72	6.450337771892052	3.4571370855028922	10
2026-05-19 14:13:19.872748	S72	6.448695648878683	3.4603350160395987	11
2026-05-19 14:13:19.872748	S72	6.448352268536865	3.464109564303319	12
2026-05-19 14:13:19.872748	S72	6.449602209922105	3.4681309163340464	13
2026-05-19 14:13:19.872748	S72	6.450683539517145	3.46880703584504	14
2026-05-19 14:13:19.872748	S72	6.4570939819717434	3.4671884381235296	15
2026-05-19 14:13:19.872748	S72	6.458769543949753	3.4665330084280246	16
2026-05-19 14:13:19.872748	S72	6.461793344595175	3.467863763780668	17
2026-05-19 14:13:19.872748	S72	6.465039595395371	3.469690136601712	18
2026-05-19 14:13:19.872748	S72	6.48478434606249	3.4783172665619215	19
2026-05-19 14:13:19.872748	S72	6.495027062974075	3.5005036119888184	20
2026-05-19 14:13:19.872748	S72	6.502692439003338	3.52047048936637	21
2026-05-19 14:13:19.872748	S72	6.510013503085395	3.5569225026536273	22
2026-05-19 14:13:19.872748	S72	6.520679855749293	3.599435013678392	23
2026-05-19 14:13:19.872748	S72	6.512190390299193	3.6152369945644622	24
2026-05-19 14:13:19.872748	S73	6.436702621424786	3.4419826471853696	1
2026-05-19 14:13:19.872748	S73	6.437183644250093	3.443633869921191	2
2026-05-19 14:13:19.872748	S73	6.438169638974981	3.449172682809203	3
2026-05-19 14:13:19.872748	S73	6.440341394711923	3.452068097740721	4
2026-05-19 14:13:19.872748	S73	6.4427855	3.4522185	5
2026-05-19 14:13:19.872748	S73	6.448029335881293	3.451680566782649	6
2026-05-19 14:13:19.872748	S73	6.450325379698088	3.45198417588239	7
2026-05-19 14:13:19.872748	S73	6.451501864959586	3.453691977068437	8
2026-05-19 14:13:19.872748	S73	6.451425493952544	3.456310961143582	9
2026-05-19 14:13:19.872748	S73	6.450800690217472	3.458185372348801	10
2026-05-19 14:13:19.872748	S73	6.450097786015514	3.459981683087135	11
2026-05-19 14:13:19.872748	S73	6.449941585081747	3.461621792891702	12
2026-05-19 14:13:19.872748	S73	6.450058735782072	3.462910450595289	13
2026-05-19 14:13:19.872748	S73	6.450488288349935	3.463925756664783	14
2026-05-19 14:13:19.872748	S73	6.45115214231845	3.465370615302139	15
2026-05-19 14:13:19.872748	S73	6.452050297687618	3.465917318570328	16
2026-05-19 14:13:19.872748	S73	6.453182754457437	3.465526816235907	17
2026-05-19 14:13:19.872748	S73	6.454627613094793	3.465097263668045	18
2026-05-19 14:13:19.872748	S73	6.461188052313059	3.464667711100182	19
2026-05-19 14:13:19.872748	S73	6.546364120268855	3.455297283249439	20
2026-05-19 14:13:19.872748	S73	6.581416478339578	3.4754239121114496	21
2026-05-19 14:13:19.872748	S73	6.591761191251312	3.480935439482427	22
2026-05-19 14:13:19.872748	S73	6.601832	3.4862304	23
2026-05-19 14:13:19.872748	S74	6.436702621424786	3.4419826471853696	1
2026-05-19 14:13:19.872748	S74	6.437148872682446	3.443652829220567	2
2026-05-19 14:13:19.872748	S74	6.438060596948415	3.4492206733569892	3
2026-05-19 14:13:19.872748	S74	6.440284090899568	3.4521801196018203	4
2026-05-19 14:13:19.872748	S74	6.442730172633206	3.452134981486707	5
2026-05-19 14:13:19.872748	S74	6.447846400128215	3.451558467611073	6
2026-05-19 14:13:19.872748	S74	6.450399148409349	3.451900657369097	7
2026-05-19 14:13:19.872748	S74	6.4515664124350325	3.453534219879308	8
2026-05-19 14:13:19.872748	S74	6.451471599300066	3.456468718333933	9
2026-05-19 14:13:19.872748	S74	6.45018077585767	3.459963123417252	10
2026-05-19 14:13:19.872748	S74	6.44993886153096	3.462956849768788	11
2026-05-19 14:13:19.872748	S74	6.450956541010613	3.4654748288001587	12
2026-05-19 14:13:19.872748	S74	6.452015779873845	3.4660678491780827	13
2026-05-19 14:13:19.872748	S74	6.4543247320129	3.4669495899828204	14
2026-05-19 14:13:19.872748	S74	6.457957823899161	3.466164974355203	15
2026-05-19 14:13:19.872748	S74	6.463263002624687	3.467441496144815	16
2026-05-19 14:13:19.872748	S74	6.493191767178526	3.4715500698139303	17
2026-05-19 14:13:19.872748	S74	6.510762951724724	3.5066113714975953	18
2026-05-19 14:13:19.872748	S74	6.536139	3.553069	19
2026-05-19 14:13:19.872748	S75	6.4477052	3.3749219	1
2026-05-19 14:13:19.872748	S75	6.4569343602412825	3.378431146034248	2
2026-05-19 14:13:19.872748	S75	6.462345748607691	3.37916756677424	3
2026-05-19 14:13:19.872748	S75	6.462725988442628	3.381397091294863	4
2026-05-19 14:13:19.872748	S75	6.462734506635153	3.382478301866796	5
2026-05-19 14:13:19.872748	S75	6.476506600908474	3.3921029720063465	6
2026-05-19 14:13:19.872748	S75	6.490659963728727	3.4020154302070407	7
2026-05-19 14:13:19.872748	S75	6.499307718415354	3.4084683094008854	8
2026-05-19 14:13:19.872748	S75	6.509164445300138	3.4161789863385765	9
2026-05-19 14:13:19.872748	S75	6.528023749728938	3.4309555872458875	10
2026-05-19 14:13:19.872748	S75	6.534512963056458	3.435419391044161	11
2026-05-19 14:13:19.872748	S75	6.543858022310042	3.441817453745455	12
2026-05-19 14:13:19.872748	S75	6.55993250286694	3.4529479673154357	13
2026-05-19 14:13:19.872748	S75	6.567585389412294	3.458378900565937	14
2026-05-19 14:13:19.872748	S75	6.574704507557957	3.463594916160415	15
2026-05-19 14:13:19.872748	S75	6.589636641981524	3.4749940768003977	16
2026-05-19 14:13:19.872748	S75	6.601832	3.4862304	17
2026-05-19 14:13:19.872748	S76	6.4477052	3.3749219	1
2026-05-19 14:13:19.872748	S76	6.4492081354225945	3.389713112398539	2
2026-05-19 14:13:19.872748	S77	6.474484688	3.294149195	1
2026-05-19 14:13:19.872748	S77	6.468932609854349	3.297866837009792	2
2026-05-19 14:13:19.872748	S77	6.46398727686595	3.300762619991218	3
2026-05-19 14:13:19.872748	S77	6.4590664	3.3077366	4
2026-05-19 14:13:19.872748	S89	6.5121945	3.6152349	1
2026-05-19 14:13:19.872748	S89	6.5632172	3.5890471	2
2026-05-19 14:13:19.872748	S90	6.512190235933443	3.6152373048713784	1
2026-05-19 14:13:19.872748	S90	6.521157931268647	3.5995222472382022	2
2026-05-19 14:13:19.872748	S90	6.51089830648042	3.556492646383738	3
2026-05-19 14:13:19.872748	S90	6.503825221986007	3.5199947801515648	4
2026-05-19 14:13:19.872748	S90	6.495873770170193	3.5000543268355098	5
2026-05-19 14:13:19.872748	S90	6.485553016251792	3.477666689790217	6
2026-05-19 14:13:19.872748	S90	6.461669540921629	3.4681417258979486	7
2026-05-19 14:13:19.872748	S90	6.459823157630989	3.4672572287521977	8
2026-05-19 14:13:19.872748	S90	6.456299887122844	3.4679468834965386	9
2026-05-19 14:13:19.872748	S90	6.450722255803528	3.4689499000525723	10
2026-05-19 14:13:19.872748	S90	6.449394881813557	3.46841653351062	11
2026-05-19 14:13:19.872748	S90	6.448484749530905	3.464109564303319	12
2026-05-19 14:13:19.872748	S90	6.44886426090558	3.460371377262751	13
2026-05-19 14:13:19.872748	S90	6.449737137067338	3.458511771526834	14
2026-05-19 14:13:19.872748	S90	6.450458208679223	3.457088603871795	15
2026-05-19 14:13:19.872748	S90	6.450799768916433	3.455741338491692	16
2026-05-19 14:13:19.872748	S90	6.450742842210231	3.454242268561718	17
2026-05-19 14:13:19.872748	S90	6.450382306404288	3.453426319106163	18
2026-05-19 14:13:19.872748	S90	6.450021770598346	3.452667296356809	19
2026-05-19 14:13:19.872748	S90	6.449338650123927	3.452591394081874	20
2026-05-19 14:13:19.872748	S90	6.443759832916176	3.452762174200478	21
2026-05-19 14:13:19.872748	S90	6.440872262549842	3.452305327720838	22
2026-05-19 14:13:19.872748	S90	6.44041287261651	3.4517600465674207	23
2026-05-19 14:13:19.872748	S90	6.438568963822696	3.4489514224324176	24
2026-05-19 14:13:19.872748	S90	6.437617514059485	3.445227667103255	25
2026-05-19 14:13:19.872748	S90	6.437749621236024	3.4431819296734303	26
2026-05-19 14:13:19.872748	S90	6.4398649779838895	3.439678972282833	27
2026-05-19 14:13:19.872748	S90	6.441861263833	3.435696286029653	28
2026-05-19 14:13:19.872748	S90	6.441843603832906	3.430404905284351	29
2026-05-19 14:13:19.872748	S90	6.442095819404855	3.427175929330542	30
2026-05-19 14:13:19.872748	S91	6.512190129667568	3.6152375956363008	1
2026-05-19 14:13:19.872748	S91	6.533090026688282	3.6276820780229726	2
2026-05-19 14:13:19.872748	S91	6.558735551880432	3.6414235770015217	3
2026-05-19 14:13:19.872748	S91	6.561326018985101	3.6411438765730493	4
2026-05-19 14:13:19.872748	S91	6.5624713348154025	3.6406805514803344	5
2026-05-19 14:13:19.872748	S91	6.563172203228879	3.640324374369044	6
2026-05-19 14:13:19.872748	S91	6.563707003418976	3.640220691492774	7
2026-05-19 14:13:19.872748	S91	6.564078525106597	3.6402554044713717	8
2026-05-19 14:13:19.872748	S91	6.564709928394159	3.64004019065142	9
2026-05-19 14:13:19.872748	S91	6.565193131423041	3.639972362413536	10
2026-05-19 14:13:19.872748	S91	6.565679793195663	3.6399366370460475	11
2026-05-19 14:13:19.872748	S91	6.566975144177748	3.6394155664758117	12
2026-05-19 14:13:19.872748	S91	6.567571857361696	3.638903478516565	13
2026-05-19 14:13:19.872748	S91	6.568570668053103	3.6381986367689367	14
2026-05-19 14:13:19.872748	S91	6.569557843002497	3.6371527780015467	15
2026-05-19 14:13:19.872748	S91	6.570277887448642	3.636668447954762	16
2026-05-19 14:13:19.872748	S91	6.5713246268162	3.636112641654128	17
2026-05-19 14:13:19.872748	S92	6.5121898779015055	3.6152376980551537	1
2026-05-19 14:13:19.872748	S92	6.513740573721314	3.616397550098327	2
2026-05-19 14:13:19.872748	S92	6.51395443049776	3.618240456707996	3
2026-05-19 14:13:19.872748	S92	6.513150676698902	3.620678072972826	4
2026-05-19 14:13:19.872748	S92	6.509278152641569	3.6246612410186074	5
2026-05-19 14:13:19.872748	S92	6.504684408302328	3.627275190194908	6
2026-05-19 14:13:19.872748	S92	6.50069993542219	3.6287200743357744	7
2026-05-19 14:13:19.872748	S94	6.500699929759122	3.628719474857945	1
2026-05-19 14:13:19.872748	S94	6.502267038329876	3.6269291891281625	2
2026-05-19 14:13:19.872748	S95	6.577534639861369	3.9752401726209143	1
2026-05-19 14:13:19.872748	S95	6.57634810509871	3.976508985570547	2
2026-05-19 14:13:19.872748	S95	6.5684511923843445	4.008662465225285	3
2026-05-19 14:13:19.872748	S95	6.552440451874645	4.04582355834026	4
2026-05-19 14:13:19.872748	S95	6.549472645810383	4.072548270835057	5
2026-05-19 14:13:19.872748	S95	6.547768614980537	4.075313314855073	6
2026-05-19 14:13:19.872748	S95	6.546255786557161	4.079252347695174	7
2026-05-19 14:13:19.872748	S95	6.544913148748705	4.082631106633698	8
2026-05-19 14:13:19.872748	S95	6.513047566237887	4.124803559549264	9
2026-05-19 14:13:19.872748	S95	6.423744531637354	4.173015035543756	10
2026-05-19 14:13:19.872748	S95	6.42831806686533	4.20884612009263	11
2026-05-19 14:13:19.872748	S95	6.418050827209271	4.221539839273447	12
2026-05-19 14:13:19.872748	S95	6.415410646404425	4.234823963996718	13
2026-05-19 14:13:19.872748	S95	6.418344179787681	4.2528313330658705	14
2026-05-19 14:13:19.872748	S95	6.404471681473467	4.2690890509226165	15
2026-05-19 14:13:19.872748	S95	6.403684169390516	4.280183449321754	16
2026-05-19 14:13:19.872748	S95	6.406769582646838	4.287833237635624	17
2026-05-19 14:13:19.872748	S95	6.408999852369433	4.296725989791895	18
2026-05-19 14:13:19.872748	S95	6.407523279318568	4.305145845720318	19
2026-05-19 14:13:19.872748	S95	6.41018110773193	4.3553678099030435	20
2026-05-19 14:13:19.872748	S95	6.386429815495447	4.532417638771761	21
2026-05-19 14:13:19.872748	S95	6.372128171480568	4.579859627605572	22
2026-05-19 14:13:19.872748	S95	6.361422887418939	4.601163695736574	23
2026-05-19 14:13:19.872748	S95	6.360135003905015	4.612389476363319	24
2026-05-19 14:13:19.872748	S95	6.357149205673082	4.61608705199032	25
2026-05-19 14:13:19.872748	S95	6.33917977835209	4.6271060642208965	26
2026-05-19 14:13:19.872748	S95	6.338434663375494	4.643350235506404	27
2026-05-19 14:13:19.872748	S95	6.337632095677435	4.650726543915226	28
2026-05-19 14:13:19.872748	S95	6.333500111492114	4.656677802104184	29
2026-05-19 14:13:19.872748	S95	6.3168956594825545	4.662405624647988	30
2026-05-19 14:13:19.872748	S95	6.305360048881965	4.6689893134388285	31
2026-05-19 14:13:19.872748	S95	6.296910102643203	4.671669805887049	32
2026-05-19 14:13:19.872748	S95	6.29079867564711	4.674969608516989	33
2026-05-19 14:13:19.872748	S96	6.577535064325261	3.9752417844242984	1
2026-05-19 14:13:19.872748	S96	6.576648940218519	3.9767763661495223	2
2026-05-19 14:13:19.872748	S96	6.571469043395766	4.010187516126621	3
2026-05-19 14:13:19.872748	S96	6.553444550003405	4.04619328109996	4
2026-05-19 14:13:19.872748	S96	6.550536682173345	4.072791255530234	5
2026-05-19 14:13:19.872748	S96	6.547770384694019	4.0772989399326605	6
2026-05-19 14:13:19.872748	S96	6.53873156286474	4.098672316381027	7
2026-05-19 14:13:19.872748	S96	6.523173256870649	4.187126458946139	8
2026-05-19 14:13:19.872748	S96	6.5182992422275134	4.192336731520612	9
2026-05-19 14:13:19.872748	S97	6.577534389341622	3.9752412406168105	1
2026-05-19 14:13:19.872748	S97	6.576101856992665	3.976279941126762	2
2026-05-19 14:13:19.872748	S97	6.566266959507168	4.008631272856206	3
2026-05-19 14:13:19.872748	S97	6.550264711797098	4.044984664456393	4
2026-05-19 14:13:19.872748	S97	6.546381371274705	4.070264997175144	5
2026-05-19 14:13:19.872748	S97	6.546786982248236	4.073688502062083	6
2026-05-19 14:13:19.872748	S97	6.545818903452343	4.078833697698428	7
2026-05-19 14:13:19.872748	S97	6.544419745770227	4.08181582205809	8
2026-05-19 14:13:19.872748	S97	6.538984505439771	4.086911134106316	9
2026-05-19 14:13:19.872748	S97	6.5307283410364505	4.095291951013024	10
2026-05-19 14:13:19.872748	S97	6.519404084681582	4.095193050826737	11
2026-05-19 14:13:19.872748	S98	6.577533438070972	3.9752393663239047	1
2026-05-19 14:13:19.872748	S98	6.570314483998644	3.975275479074128	2
2026-05-19 14:13:19.872748	S98	6.570156049365892	3.975331521760552	3
2026-05-19 14:13:19.872748	S98	6.569926762073607	3.975488145388397	4
2026-05-19 14:13:19.872748	S98	6.569710721974758	3.975568041676354	5
2026-05-19 14:13:19.872748	S98	6.569503831506992	3.9755929401759715	6
2026-05-19 14:13:19.872748	S98	6.569381310531362	3.97559441695968	7
2026-05-19 14:13:19.872748	S98	6.569298757767427	3.975577606299453	8
2026-05-19 14:13:19.872748	S98	6.567460290853333	3.975345225146924	9
2026-05-19 14:13:19.872748	S103	6.571324058042505	3.6361133776478773	1
2026-05-19 14:13:19.872748	S103	6.570517205299881	3.6364410992661482	2
2026-05-19 14:13:19.872748	S103	6.569587298005848	3.636850284520597	3
2026-05-19 14:13:19.872748	S103	6.568912029991193	3.637711207682802	4
2026-05-19 14:13:19.872748	S103	6.56795529496681	3.638554422911626	5
2026-05-19 14:13:19.872748	S103	6.566969537705788	3.6392599102685477	6
2026-05-19 14:13:19.872748	S103	6.56552396324178	3.639868788042304	7
2026-05-19 14:13:19.872748	S103	6.564817244105014	3.639942000847636	8
2026-05-19 14:13:19.872748	S103	6.564116797159597	3.6401127984504407	9
2026-05-19 14:13:19.872748	S103	6.563726156779717	3.640137491353304	10
2026-05-19 14:13:19.872748	S103	6.563139200510612	3.6402383494264763	11
2026-05-19 14:13:19.872748	S103	6.562284191067973	3.640618345248004	12
2026-05-19 14:13:19.872748	S103	6.56175669948802	3.640788167076506	13
2026-05-19 14:13:19.872748	S103	6.561320710031739	3.640977463371349	14
2026-05-19 14:13:19.872748	S103	6.5594992354930355	3.6406513064532398	15
2026-05-19 14:13:19.872748	S103	6.553240658637177	3.6378635418473104	16
2026-05-19 14:13:19.872748	S103	6.52834850871486	3.5608503479673628	17
2026-05-19 14:13:19.872748	S103	6.4881209862702836	3.474683673103219	18
2026-05-19 14:13:19.872748	S103	6.4672000326018475	3.389826339956497	19
2026-05-19 14:13:19.872748	S103	6.462734251023672	3.3824784268227193	20
2026-05-19 14:13:19.872748	S103	6.462328890415979	3.380948205040011	21
2026-05-19 14:13:19.872748	S103	6.4619783201816	3.37944097444534	22
2026-05-19 14:13:19.872748	S103	6.456921465295597	3.3793270599893406	23
2026-05-19 14:13:19.872748	S103	6.453425670147038	3.380500539105184	24
2026-05-19 14:13:19.872748	S103	6.451568610830791	3.3829436810600813	25
2026-05-19 14:13:19.872748	S103	6.44920784535947	3.3897127927105384	26
2026-05-19 14:13:19.872748	S107	6.56021613	3.600195878	1
2026-05-19 14:13:19.872748	S107	6.535112666286517	3.569401876233332	2
2026-05-19 14:13:19.872748	S107	6.519839905146939	3.5379806126384445	3
2026-05-19 14:13:19.872748	S107	6.489557489539898	3.474129030915237	4
2026-05-19 14:13:19.872748	S107	6.4598769884752425	3.4674368315450392	5
2026-05-19 14:13:19.872748	S107	6.454349244706966	3.467432513539869	6
2026-05-19 14:13:19.872748	S107	6.450363852820928	3.4674906950004107	7
2026-05-19 14:13:19.872748	S107	6.449021965769328	3.4616461078162213	8
2026-05-19 14:13:19.872748	S107	6.450173575148216	3.456063923160168	9
2026-05-19 14:13:19.872748	S107	6.450211526285684	3.454887437898669	10
2026-05-19 14:13:19.872748	S107	6.449850990479741	3.453843781618307	11
2026-05-19 14:13:19.872748	S107	6.449433527967596	3.453179636712623	12
2026-05-19 14:13:19.872748	S107	6.447820604625219	3.453198612281357	13
2026-05-19 14:13:19.872748	S107	6.443835735191111	3.453521196949832	14
2026-05-19 14:13:19.872748	S107	6.440420132819018	3.45306578330022	15
2026-05-19 14:13:19.872748	S107	6.440075433703385	3.4525339842229736	16
2026-05-19 14:13:19.872748	S107	6.437691933633133	3.4493676476471493	17
2026-05-19 14:13:19.872748	S107	6.437007436003763	3.4436816640243295	18
2026-05-19 14:13:19.872748	S107	6.436702379801346	3.4419823331789634	19
2026-05-19 14:13:19.872748	S107	6.438483241421429	3.439986734480111	20
2026-05-19 14:13:19.872748	S107	6.441222097325601	3.4358022402648345	21
2026-05-19 14:13:19.872748	S107	6.441284892252207	3.435604924065667	22
2026-05-19 14:13:19.872748	S107	6.440934108053681	3.4274563000862353	23
2026-05-19 14:13:19.872748	S107	6.439906441125591	3.423850870487048	24
2026-05-19 14:13:19.872748	S107	6.438886919966006	3.421846989424669	25
2026-05-19 14:13:19.872748	S107	6.437840304024391	3.418141158658537	26
2026-05-19 14:13:19.872748	S107	6.438160927237535	3.415964966706243	27
2026-05-19 14:13:19.872748	S107	6.438961000856666	3.41363882673951	28
2026-05-19 14:13:19.872748	S107	6.43942030237876	3.412453532488946	29
2026-05-19 14:13:19.872748	S107	6.441050081973286	3.410157024878477	30
2026-05-19 14:13:19.872748	S107	6.441716809989227	3.40823092172131	31
2026-05-19 14:13:19.872748	S107	6.441850155592416	3.406408531811068	32
2026-05-19 14:13:19.872748	S107	6.441613096742303	3.405223237560503	33
2026-05-19 14:13:19.872748	S107	6.440753758410644	3.403993494775542	34
2026-05-19 14:13:19.872748	S107	6.439983317147777	3.40311934026575	35
2026-05-19 14:13:19.872748	S107	6.439257324419307	3.402585957852997	36
2026-05-19 14:13:19.872748	S107	6.439212875884912	3.402378531359149	37
2026-05-19 14:13:19.872748	S107	6.439257324419307	3.40203775926211	38
2026-05-19 14:13:19.872748	S107	6.4492081354225945	3.389713112398539	39
2026-05-19 14:13:19.872748	S108	6.437342371	3.310792342	1
2026-05-19 14:13:19.872748	S108	6.432069477432194	3.3194089632410453	2
2026-05-19 14:13:19.872748	S108	6.431888045331661	3.3209642887536006	3
2026-05-19 14:13:19.872748	S108	6.432264567103331	3.3229966073384674	4
2026-05-19 14:13:19.872748	S108	6.435841510024574	3.3286457640850244	5
2026-05-19 14:13:19.872748	S108	6.437324709657744	3.3346685278221173	6
2026-05-19 14:13:19.872748	S108	6.43748244228334	3.3379313820809386	7
2026-05-19 14:13:19.872748	S108	6.435568447600829	3.3474730261550576	8
2026-05-19 14:13:19.872748	S108	6.435617970980985	3.3483202624996977	9
2026-05-19 14:13:19.872748	S108	6.43866364959888	3.355521771428812	10
2026-05-19 14:13:19.872748	S108	6.439059834092319	3.358312667621732	11
2026-05-19 14:13:19.872748	S108	6.4390639714181646	3.359173604139272	12
2026-05-19 14:13:19.872748	S108	6.431552015158104	3.365812882420073	13
2026-05-19 14:13:19.872748	S108	6.4356693835266725	3.3806475009272674	14
2026-05-19 14:13:19.872748	S108	6.432975306762131	3.3919013494485455	15
2026-05-19 14:13:19.872748	S108	6.433076970295701	3.3963005811434357	16
2026-05-19 14:13:19.872748	S108	6.438553624866415	3.3977489450779217	17
2026-05-19 14:13:19.872748	S108	6.4492081354225945	3.389713112398539	18
2026-05-19 14:13:19.872748	S109	6.437342371	3.310792342	1
2026-05-19 14:13:19.872748	S109	6.435188556554522	3.314447678953428	2
2026-05-19 14:13:19.872748	S109	6.433451695939439	3.3176795430389916	3
2026-05-19 14:13:19.872748	S109	6.433095393408948	3.3185759439852234	4
2026-05-19 14:13:19.872748	S109	6.432699501415698	3.3197910652698113	5
2026-05-19 14:13:19.872748	S109	6.433340200810306	3.3200148676967274	6
2026-05-19 14:13:19.872748	S109	6.445828594321938	3.31541941035141	7
2026-05-19 14:13:19.872748	S109	6.452056391271142	3.312939475722544	8
2026-05-19 14:13:19.872748	S109	6.455180912040234	3.3108338195200133	9
2026-05-19 14:13:19.872748	S109	6.4590664	3.3077366	10
2026-05-19 14:13:19.872748	S111	6.453176016321364	3.204245472039803	1
2026-05-19 14:13:19.872748	S111	6.451306611466339	3.204691272048581	2
2026-05-19 14:13:19.872748	S111	6.447691481869566	3.206286535856859	3
2026-05-19 14:13:19.872748	S111	6.446734703680288	3.207021241535907	4
2026-05-19 14:13:19.872748	S111	6.446451639933496	3.207058983368812	5
2026-05-19 14:13:19.872748	S111	6.446220471206949	3.207073136556152	6
2026-05-19 14:13:19.872748	S111	6.446017608855081	3.20701180607768	7
2026-05-19 14:13:19.872748	S111	6.445489223194404	3.206874991933397	8
2026-05-19 14:13:19.872748	S111	6.445215594905838	3.206851403287831	9
2026-05-19 14:13:19.872748	S111	6.444706080161613	3.206804225996699	10
2026-05-19 14:13:19.872748	S111	6.444432747288471	3.206754564188978	11
2026-05-19 14:13:19.872748	S111	6.444041559428788	3.206611361490344	12
2026-05-19 14:13:19.872748	S111	6.443884385735166	3.206527535520412	13
2026-05-19 14:13:19.872748	S111	6.443779603272752	3.206503086279182	14
2026-05-19 14:13:19.872748	S111	6.443469776041071	3.206911246986321	15
2026-05-19 14:13:19.872748	S111	6.443091325419357	3.207035222189985	16
2026-05-19 14:13:19.872748	S111	6.442796068684314	3.207031959684626	17
2026-05-19 14:13:19.872748	S179	6.58083	3.4078701	8
2026-05-19 14:13:19.872748	S111	6.442169667655271	3.207031959684626	18
2026-05-19 14:13:19.872748	S111	6.442053848715006	3.207009122147109	19
2026-05-19 14:13:19.872748	S111	6.441954138394951	3.206969564269626	20
2026-05-19 14:13:19.872748	S111	6.441885829688987	3.206950397050636	21
2026-05-19 14:13:19.872748	S111	6.441900522322349	3.206819560367967	22
2026-05-19 14:13:19.872748	S111	6.44193717899138	3.206682097859101	23
2026-05-19 14:13:19.872748	S111	6.442025765941538	3.206556854239912	24
2026-05-19 14:13:19.872748	S111	6.442205994564274	3.206275819777342	25
2026-05-19 14:13:19.872748	S111	6.44230374568169	3.206031441983802	26
2026-05-19 14:13:19.872748	S111	6.442395387354266	3.205793173635101	27
2026-05-19 14:13:19.872748	S111	6.442386223187009	3.205686258350428	28
2026-05-19 14:13:19.872748	S111	6.442374004297332	3.205310527492861	29
2026-05-19 14:13:19.872748	S111	6.442248760678145	3.205050876087226	30
2026-05-19 14:13:19.872748	S111	6.442053258443313	3.204772896347075	31
2026-05-19 14:13:19.872748	S111	6.441714184254777	3.204284140759996	32
2026-05-19 14:13:19.872748	S111	6.441414821457691	3.203948121293879	33
2026-05-19 14:13:19.872748	S111	6.441369527365509	3.203789150136757	34
2026-05-19 14:13:19.872748	S111	6.441268060756738	3.203600712149039	35
2026-05-19 14:13:19.872748	S111	6.441178615486484	3.203392676480475	36
2026-05-19 14:13:19.872748	S111	6.441130799785653	3.203386699517871	37
2026-05-19 14:13:19.872748	S111	6.440997314287503	3.203358807025721	38
2026-05-19 14:13:19.872748	S111	6.440841913259805	3.203332906854437	39
2026-05-19 14:13:19.872748	S111	6.440680535269504	3.203299037399683	40
2026-05-19 14:13:19.872748	S111	6.440503218712259	3.203251221698853	41
2026-05-19 14:13:19.872748	S111	6.440395633385391	3.203231298490174	42
2026-05-19 14:13:19.872748	S111	6.440290040379391	3.203245244736249	43
2026-05-19 14:13:19.872748	S111	6.440241033406033	3.203238129548885	44
2026-05-19 14:13:19.872748	S111	6.440090881864421	3.203245732158587	45
2026-05-19 14:13:19.872748	S111	6.440049067511061	3.203253334768289	46
2026-05-19 14:13:19.872748	S111	6.440017658768764	3.203237227199949	47
2026-05-19 14:13:19.872748	S111	6.439907346520113	3.203113913993497	48
2026-05-19 14:13:19.872748	S111	6.439859522026505	3.203059773057337	49
2026-05-19 14:13:19.872748	S111	6.439782976171497	3.202975839514171	50
2026-05-19 14:13:19.872748	S111	6.439673585476046	3.202875950657815	51
2026-05-19 14:13:19.872748	S111	6.43958688975491	3.202806617388411	52
2026-05-19 14:13:19.872748	S111	6.439535973431276	3.202761060677791	53
2026-05-19 14:13:19.872748	S111	6.439503815753192	3.202744981838749	54
2026-05-19 14:13:19.872748	S111	6.439444860010037	3.202661907837032	55
2026-05-19 14:13:19.872748	S111	6.439329628330236	3.202503799253118	56
2026-05-19 14:13:19.872748	S111	6.439096485164126	3.202198301311318	57
2026-05-19 14:13:19.872748	S111	6.438649159270327	3.202039905356677	58
2026-05-19 14:13:19.872748	S111	6.438634797642549	3.202036314949733	59
2026-05-19 14:13:19.872748	S111	6.438582941520941	3.202044064682965	60
2026-05-19 14:13:19.872748	S111	6.438353316713476	3.202058903121032	61
2026-05-19 14:13:19.872748	S111	6.438179991338727	3.202069670598982	62
2026-05-19 14:13:19.872748	S111	6.437928089527067	3.202024113888362	63
2026-05-19 14:13:19.872748	S111	6.437775849379801	3.202000121152798	64
2026-05-19 14:13:19.872748	S111	6.437750730276349	3.201913346068144	65
2026-05-19 14:13:19.872748	S111	6.437481633442951	3.200908287509451	66
2026-05-19 14:13:19.872748	S111	6.437172448732188	3.199729685962439	67
2026-05-19 14:13:19.872748	S111	6.436724445702199	3.199509817228341	68
2026-05-19 14:13:19.872748	S111	6.436292210738742	3.199493808525991	69
2026-05-19 14:13:19.872748	S111	6.435795940965884	3.199541834633042	70
2026-05-19 14:13:19.872748	S111	6.435235636383625	3.199637886847143	71
2026-05-19 14:13:19.872748	S111	6.434339149052009	3.199862008680047	72
2026-05-19 14:13:19.872748	S111	6.43346280646663	3.199893132458986	73
2026-05-19 14:13:19.872748	S111	6.432551380529413	3.199323491248226	74
2026-05-19 14:13:19.872748	S111	6.431241205744664	3.199295009187688	75
2026-05-19 14:13:19.872748	S111	6.428791748538393	3.199437419490378	76
2026-05-19 14:13:19.872748	S111	6.427111306966649	3.19955134773253	77
2026-05-19 14:13:19.872748	S111	6.425146044789524	3.19926652712715	78
2026-05-19 14:13:19.872748	S111	6.421842125767112	3.198867778279618	79
2026-05-19 14:13:19.872748	S111	6.419551370070374	3.199291203265197	80
2026-05-19 14:13:19.872748	S111	6.4185382067447	3.198753850037465	81
2026-05-19 14:13:19.872748	S111	6.417313478141565	3.199181080945536	82
2026-05-19 14:13:19.872748	S111	6.41637357014381	3.199608311853606	83
2026-05-19 14:13:19.872748	S111	6.41594633923574	3.202484999967948	84
2026-05-19 14:13:19.872748	S111	6.415433662146055	3.205304723961213	85
2026-05-19 14:13:19.872748	S111	6.415927806687773	3.210824404637061	86
2026-05-19 14:13:19.872748	S111	6.415280941066423	3.211848608537532	87
2026-05-19 14:13:19.872748	S111	6.414526264508182	3.212657190564219	88
2026-05-19 14:13:19.872748	S111	6.406683018849317	3.205541668729372	89
2026-05-19 14:13:19.872748	S112	6.453176023250619	3.204245483565353	1
2026-05-19 14:13:19.872748	S112	6.453167315513737	3.204254438520946	2
2026-05-19 14:13:19.872748	S112	6.45212890705691	3.205189708964279	3
2026-05-19 14:13:19.872748	S112	6.451110477673626	3.20600831992426	4
2026-05-19 14:13:19.872748	S112	6.444027833691879	3.212150880467128	5
2026-05-19 14:13:19.872748	S112	6.436800085043404	3.2196807000499117	6
2026-05-19 14:13:19.872748	S112	6.433341994044476	3.2279077782567	7
2026-05-19 14:13:19.872748	S112	6.428149792562023	3.2391552166842335	8
2026-05-19 14:13:19.872748	S112	6.426293855282433	3.242830018360153	9
2026-05-19 14:13:19.872748	S112	6.422836136097881	3.24376192989665	10
2026-05-19 14:13:19.872748	S112	6.417382039815242	3.243496349985531	11
2026-05-19 14:13:19.872748	S112	6.411338005772572	3.25130128973135	12
2026-05-19 14:13:19.872748	S112	6.407580321328695	3.261600491251755	13
2026-05-19 14:13:19.872748	S113	6.453176022	3.204245481	1
2026-05-19 14:13:19.872748	S113	6.451213609763073	3.205776272723006	2
2026-05-19 14:13:19.872748	S113	6.442439488371421	3.212697757950497	3
2026-05-19 14:13:19.872748	S113	6.441483166547236	3.212715862091557	4
2026-05-19 14:13:19.872748	S113	6.441552727834017	3.21263238854742	5
2026-05-19 14:13:19.872748	S113	6.441800366014954	3.212373620560597	6
2026-05-19 14:13:19.872748	S113	6.441936706137044	3.212039726384052	7
2026-05-19 14:13:19.872748	S113	6.441945053491457	3.211878344198722	8
2026-05-19 14:13:19.872748	S113	6.44192835878263	3.21157505698836	9
2026-05-19 14:13:19.872748	S113	6.441886622010562	3.211516625507465	10
2026-05-19 14:13:19.872748	S113	6.441694632859049	3.211268987326527	11
2026-05-19 14:13:19.872748	S113	6.441602811960498	3.211082563077956	12
2026-05-19 14:13:19.872748	S113	6.441647331184038	3.210851619605845	13
2026-05-19 14:13:19.872748	S113	6.441594464606085	3.210698584774929	14
2026-05-19 14:13:19.872748	S113	6.44146925428988	3.21067910761463	15
2026-05-19 14:13:19.872748	S113	6.441316219458963	3.210648500648447	16
2026-05-19 14:13:19.872748	S113	6.441129795210393	3.210612328779321	17
2026-05-19 14:13:19.872748	S113	6.441115882953037	3.210373037952797	18
2026-05-19 14:13:19.872748	S113	6.441191009142759	3.210222785573352	19
2026-05-19 14:13:19.872748	S113	6.441338479070733	3.209908368557105	20
2026-05-19 14:13:19.872748	S113	6.441352391328089	3.209593951540858	21
2026-05-19 14:13:19.872748	S113	6.441591682154614	3.20909311027604	22
2026-05-19 14:13:19.872748	S113	6.441502643707535	3.20858670410828	23
2026-05-19 14:13:19.872748	S113	6.441708545116405	3.207913350852247	24
2026-05-19 14:13:19.872748	S113	6.441786453757598	3.207284516819753	25
2026-05-19 14:13:19.872748	S113	6.441905404721144	3.206686134116508	26
2026-05-19 14:13:19.872748	S113	6.441924979753302	3.206646984052194	27
2026-05-19 14:13:19.872748	S113	6.442189242687428	3.206262008419761	28
2026-05-19 14:13:19.872748	S113	6.442202292708867	3.206229383366165	29
2026-05-19 14:13:19.872748	S113	6.442365417976847	3.205795470153339	30
2026-05-19 14:13:19.872748	S113	6.442349105450049	3.205328931886917	31
2026-05-19 14:13:19.872748	S113	6.442238180267823	3.205080981479588	32
2026-05-19 14:13:19.872748	S113	6.442062004978404	3.204816718545461	33
2026-05-19 14:13:19.872748	S113	6.441716179410287	3.204307767709364	34
2026-05-19 14:13:19.872748	S113	6.441399374070119	3.203967593928279	35
2026-05-19 14:13:19.872748	S113	6.441349388418964	3.203788335041375	36
2026-05-19 14:13:19.872748	S113	6.441274710980389	3.203641160332373	37
2026-05-19 14:13:19.872748	S113	6.44116843429947	3.203405503344249	38
2026-05-19 14:13:19.872748	S113	6.440823982371993	3.203350837742249	39
2026-05-19 14:13:19.872748	S113	6.440407587310599	3.203249229377985	40
2026-05-19 14:13:19.872748	S113	6.440286055737656	3.20326317562406	41
2026-05-19 14:13:19.872748	S113	6.440242224678562	3.203259190982324	42
2026-05-19 14:13:19.872748	S113	6.440044984912637	3.203277121870136	43
2026-05-19 14:13:19.872748	S113	6.440031038666562	3.203267160265796	44
2026-05-19 14:13:19.872748	S113	6.439994874366905	3.203241145193472	45
2026-05-19 14:13:19.872748	S113	6.439760263643545	3.202972245210545	46
2026-05-19 14:13:19.872748	S113	6.439521141175508	3.202767412002075	47
2026-05-19 14:13:19.872748	S113	6.439497680103172	3.202754779116971	48
2026-05-19 14:13:19.872748	S113	6.439091138688628	3.202205600118752	49
2026-05-19 14:13:19.872748	S113	6.43883740158983	3.202118645270287	50
2026-05-19 14:13:19.872748	S113	6.438640208900688	3.202050221782971	51
2026-05-19 14:13:19.872748	S113	6.438631655964774	3.202049271456758	52
2026-05-19 14:13:19.872748	S113	6.438627379496817	3.202049271456758	53
2026-05-19 14:13:19.872748	S113	6.438619776887115	3.202050221782971	54
2026-05-19 14:13:19.872748	S113	6.438193177588351	3.202082990240014	55
2026-05-19 14:13:19.872748	S113	6.437769509568876	3.202018362915009	56
2026-05-19 14:13:19.872748	S113	6.437758738348042	3.20200878849649	57
2026-05-19 14:13:19.872748	S113	6.437410283125082	3.200752373851886	58
2026-05-19 14:13:19.872748	S113	6.437151307897263	3.199771967632287	59
2026-05-19 14:13:19.872748	S113	6.436900260482541	3.199655693040205	60
2026-05-19 14:13:19.872748	S113	6.436696779946398	3.19957112970051	61
2026-05-19 14:13:19.872748	S113	6.436461588157869	3.199563201887413	62
2026-05-19 14:13:19.872748	S113	6.436072537363941	3.199649632619111	63
2026-05-19 14:13:19.872748	S113	6.435071134597871	3.1999317036962562	64
2026-05-19 14:13:19.872748	S113	6.433828543093221	3.200236755101518	65
2026-05-19 14:13:19.872748	S113	6.432947858922435	3.2003070190311345	66
2026-05-19 14:13:19.872748	S113	6.432159589725955	3.1997381846599064	67
2026-05-19 14:13:19.872748	S113	6.431567291018999	3.199684248283623	68
2026-05-19 14:13:19.872748	S113	6.42706373911336	3.199979714262889	69
2026-05-19 14:13:19.872748	S113	6.42495785784266	3.1996543041362475	70
2026-05-19 14:13:19.872748	S113	6.422950812640763	3.1994467241888467	71
2026-05-19 14:13:19.872748	S113	6.421075395681876	3.1993674025848375	72
2026-05-19 14:13:19.872748	S113	6.419549122371283	3.199313162298789	73
2026-05-19 14:13:19.872748	S113	6.419394438591079	3.1991658082454473	74
2026-05-19 14:13:19.872748	S113	6.418975395484804	3.1991616114517223	75
2026-05-19 14:13:19.872748	S113	6.417568222034982	3.1998529839453553	76
2026-05-19 14:13:19.872748	S113	6.416626814828135	3.2016135999796616	77
2026-05-19 14:13:19.872748	S113	6.416292701932701	3.2049941792152783	78
2026-05-19 14:13:19.872748	S113	6.417041137533617	3.2089233226028524	79
2026-05-19 14:13:19.872748	S113	6.416269207876866	3.211665041442214	80
2026-05-19 14:13:19.872748	S113	6.413684301740902	3.215067080017983	81
2026-05-19 14:13:19.872748	S113	6.409566035152125	3.220710249046361	82
2026-05-19 14:13:19.872748	S113	6.408135629318128	3.223126060666493	83
2026-05-19 14:13:19.872748	S113	6.40835632435245	3.225238583047931	84
2026-05-19 14:13:19.872748	S113	6.412269804000883	3.230747874272814	85
2026-05-19 14:13:19.872748	S113	6.417336462	3.236747347	86
2026-05-19 14:13:19.872748	S115	6.453176023250619	3.204245483565353	1
2026-05-19 14:13:19.872748	S115	6.451046020117722	3.205144588675147	2
2026-05-19 14:13:19.872748	S115	6.447753733168739	3.206507009062568	3
2026-05-19 14:13:19.872748	S115	6.44759333037889	3.206549468624587	4
2026-05-19 14:13:19.872748	S115	6.4474895403384	3.206606081373945	5
2026-05-19 14:13:19.872748	S115	6.447263089340966	3.206757048705567	6
2026-05-19 14:13:19.872748	S115	6.446852646908118	3.207063701097925	7
2026-05-19 14:13:19.872748	S115	6.446753574596741	3.207120313847283	8
2026-05-19 14:13:19.872748	S115	6.446512970411968	3.207162773409302	9
2026-05-19 14:13:19.872748	S115	6.445913818814591	3.207077854285265	10
2026-05-19 14:13:19.872748	S115	6.445319384946329	3.206922169224529	11
2026-05-19 14:13:19.872748	S115	6.444715659936991	3.206880303143875	12
2026-05-19 14:13:19.872748	S115	6.444024095685053	3.206716143952759	13
2026-05-19 14:13:19.872748	S115	6.44379357426774	3.206611361490344	14
2026-05-19 14:13:19.872748	S115	6.443496690624233	3.206992071103785	15
2026-05-19 14:13:19.872748	S115	6.443206792478219	3.207093360817452	16
2026-05-19 14:13:19.872748	S115	6.442976271060906	3.207110824561188	17
2026-05-19 14:13:19.872748	S115	6.442218344582773	3.207093360817452	18
2026-05-19 14:13:19.872748	S115	6.441972286081016	3.207087422275739	19
2026-05-19 14:13:19.872748	S115	6.441838523361273	3.207058059727502	20
2026-05-19 14:13:19.872748	S115	6.441918250835998	3.206675938787262	21
2026-05-19 14:13:19.872748	S115	6.442209225532754	3.206243656827114	22
2026-05-19 14:13:19.872748	S115	6.442215138823721	3.206215925531559	23
2026-05-19 14:13:19.872748	S115	6.442375001586341	3.205791799834811	24
2026-05-19 14:13:19.872748	S115	6.442355426554183	3.20531873655767	25
2026-05-19 14:13:19.872748	S115	6.442244501371957	3.205077311161059	26
2026-05-19 14:13:19.872748	S115	6.442150338416655	3.20493034267917	27
2026-05-19 14:13:19.872748	S115	6.441704438429321	3.204285751505772	28
2026-05-19 14:13:19.872748	S115	6.441401780924966	3.203959990375129	29
2026-05-19 14:13:19.872748	S115	6.441354418491078	3.203785557996665	30
2026-05-19 14:13:19.872748	S115	6.441242737999472	3.203564692343531	31
2026-05-19 14:13:19.872748	S115	6.441170960117492	3.203400667163599	32
2026-05-19 14:13:19.872748	S115	6.440800074521579	3.203338883817041	33
2026-05-19 14:13:19.872748	S115	6.440642681173014	3.203299037399683	34
2026-05-19 14:13:19.872748	S115	6.440407587310599	3.203243252415381	35
2026-05-19 14:13:19.872748	S115	6.440385671781051	3.203245244736249	36
2026-05-19 14:13:19.872748	S115	6.440301994304598	3.203257198661456	37
2026-05-19 14:13:19.872748	S115	6.440246209320297	3.203249229377985	38
2026-05-19 14:13:19.872748	S115	6.440220309149014	3.203251221698853	39
2026-05-19 14:13:19.872748	S115	6.440041000270901	3.203267160265796	40
2026-05-19 14:13:19.872748	S115	6.440001551200425	3.203241930853736	41
2026-05-19 14:13:19.872748	S115	6.439760168342391	3.202966336252044	42
2026-05-19 14:13:19.872748	S115	6.439528288746485	3.202766767747371	43
2026-05-19 14:13:19.872748	S115	6.439502191847852	3.202753876768035	44
2026-05-19 14:13:19.872748	S115	6.439092172085316	3.202203687836461	45
2026-05-19 14:13:19.872748	S115	6.438640208900688	3.202045470151907	46
2026-05-19 14:13:19.872748	S115	6.438633081454093	3.202045470151907	47
2026-05-19 14:13:19.872748	S115	6.438625478844391	3.202045945315013	48
2026-05-19 14:13:19.872748	S115	6.438616925908477	3.202047845967439	49
2026-05-19 14:13:19.872748	S115	6.438311661017526	3.202071022216864	50
2026-05-19 14:13:19.872748	S115	6.438183603169832	3.202078203030754	51
2026-05-19 14:13:19.872748	S115	6.437937061892962	3.202035118147418	52
2026-05-19 14:13:19.872748	S115	6.437876024974902	3.202027937333528	53
2026-05-19 14:13:19.872748	S115	6.437765919161931	3.20200878849649	54
2026-05-19 14:13:19.872748	S115	6.437441994377468	3.20082636677412	55
2026-05-19 14:13:19.872748	S115	6.43715923571036	3.199756112006094	56
2026-05-19 14:13:19.872748	S115	6.436902903086906	3.199639837414012	57
2026-05-19 14:13:19.872748	S115	6.436702065155129	3.199552631469951	58
2026-05-19 14:13:19.872748	S115	6.436387595235635	3.199544703656855	59
2026-05-19 14:13:19.872748	S115	6.435927782076038	3.199584342722337	60
2026-05-19 14:13:19.872748	S115	6.435639738200199	3.199663620853302	61
2026-05-19 14:13:19.872748	S115	6.433215960589242	3.200208828370111	62
2026-05-19 14:13:19.872748	S115	6.432742650786587	3.19998061654438	63
2026-05-19 14:13:19.872748	S115	6.432214728753221	3.199639019934555	64
2026-05-19 14:13:19.872748	S115	6.430444637229582	3.199639019934555	65
2026-05-19 14:13:19.872748	S115	6.429171413502052	3.199794291120839	66
2026-05-19 14:13:19.872748	S115	6.427028671131331	3.199918508069866	67
2026-05-19 14:13:19.872748	S115	6.424668549099812	3.199483748748271	68
2026-05-19 14:13:19.872748	S115	6.421911313685259	3.199234728921212	69
2026-05-19 14:13:19.872748	S115	6.418784796515402	3.199046059781652	70
2026-05-19 14:13:19.872748	S115	6.417059821525136	3.199827689074116	71
2026-05-19 14:13:19.872748	S115	6.416089523093111	3.200339791024351	72
2026-05-19 14:13:19.872748	S115	6.415119224661087	3.201283136722153	73
2026-05-19 14:13:19.872748	S115	6.413293298811107	3.201965091665905	74
2026-05-19 14:13:19.872748	S115	6.410624343878806	3.20093302973272	75
2026-05-19 14:13:19.872748	S115	6.407965832784628	3.1978444058329867	76
2026-05-19 14:13:19.872748	S115	6.407439525702606	3.194183016827545	77
2026-05-19 14:13:19.872748	S115	6.408455790262489	3.19115144488051	78
2026-05-19 14:13:19.872748	S115	6.415290468459889	3.182888678124085	79
2026-05-19 14:13:19.872748	S115	6.415898823714224	3.181364634756622	80
2026-05-19 14:13:19.872748	S115	6.414920753476858	3.1785234007256182	81
2026-05-19 14:13:19.872748	S115	6.414218876271115	3.177063591210343	82
2026-05-19 14:13:19.872748	S115	6.40538835795013	3.170269042620859	83
2026-05-19 14:13:19.872748	S115	6.403912901071839	3.164837180309284	84
2026-05-19 14:13:19.872748	S116	6.437342371	3.310792342	1
2026-05-19 14:13:19.872748	S116	6.437150936171184	3.301012384192853	2
2026-05-19 14:13:19.872748	S116	6.436428317908032	3.2981628923134387	3
2026-05-19 14:13:19.872748	S116	6.429874720711359	3.2914163364721802	4
2026-05-19 14:13:19.872748	S116	6.429003670759495	3.283674839872091	5
2026-05-19 14:13:19.872748	S116	6.427621662620133	3.2788813327386195	6
2026-05-19 14:13:19.872748	S116	6.42766201003981	3.267630813765836	7
2026-05-19 14:13:19.872748	S116	6.4262228273509	3.245841069247123	8
2026-05-19 14:13:19.872748	S116	6.425662041439185	3.244424281781221	9
2026-05-19 14:13:19.872748	S116	6.416035206640465	3.243713969579543	10
2026-05-19 14:13:19.872748	S116	6.4160943493428935	3.2384064514577107	11
2026-05-19 14:13:19.872748	S116	6.411965754757007	3.231065908038463	12
2026-05-19 14:13:19.872748	S116	6.406975693375611	3.2238478038606075	13
2026-05-19 14:13:19.872748	S116	6.410321491487159	3.217619423306258	14
2026-05-19 14:13:19.872748	S116	6.415820710823457	3.211338158689849	15
2026-05-19 14:13:19.872748	S116	6.41603977492157	3.2094191172579363	16
2026-05-19 14:13:19.872748	S116	6.413957762632261	3.205365382756929	17
2026-05-19 14:13:19.872748	S116	6.41057043586253	3.2010540306941846	18
2026-05-19 14:13:19.872748	S116	6.408429181567396	3.1972635254741952	19
2026-05-19 14:13:19.872748	S116	6.408148781188985	3.1956109636745422	20
2026-05-19 14:13:19.872748	S116	6.408736383849566	3.192985716332245	21
2026-05-19 14:13:19.872748	S116	6.413790037893613	3.1863035812007303	22
2026-05-19 14:13:19.872748	S116	6.4164121355151	3.1813960515993873	23
2026-05-19 14:13:19.872748	S116	6.415087147862284	3.176481867088416	24
2026-05-19 14:13:19.872748	S116	6.41024568050698	3.17355340248042	25
2026-05-19 14:13:19.872748	S116	6.405613513451686	3.1699045841944056	26
2026-05-19 14:13:19.872748	S116	6.405174562816368	3.1675188181678475	27
2026-05-19 14:13:19.872748	S116	6.405657144137003	3.1634104690435154	28
2026-05-19 14:13:19.872748	S116	6.4081739241353795	3.160678520524507	29
2026-05-19 14:13:19.872748	S116	6.412386431257103	3.1549764732776264	30
2026-05-19 14:13:19.872748	S116	6.412608284952636	3.148958161564586	31
2026-05-19 14:13:19.872748	S116	6.410716249673231	3.138979462513017	32
2026-05-19 14:13:19.872748	S116	6.411432182297421	3.129707655600916	33
2026-05-19 14:13:19.872748	S116	6.413118918284677	3.123114630602703	34
2026-05-19 14:13:19.872748	S116	6.414521483330968	3.1151729611559573	35
2026-05-19 14:13:19.872748	S116	6.409392895256172	3.103467043658066	36
2026-05-19 14:13:19.872748	S116	6.407478631534756	3.095713919592437	37
2026-05-19 14:13:19.872748	S116	6.410861403026502	3.0822665545953467	38
2026-05-19 14:13:19.872748	S116	6.410270902562877	3.0757148441561224	39
2026-05-19 14:13:19.872748	S116	6.410058482118311	3.068360260724858	40
2026-05-19 14:13:19.872748	S116	6.410218208566659	3.06667207549188	41
2026-05-19 14:13:19.872748	S116	6.415716270377361	3.0622132680803262	42
2026-05-19 14:13:19.872748	S116	6.416326466631423	3.0613208326720356	43
2026-05-19 14:13:19.872748	S116	6.415215797778185	3.0502155667296167	44
2026-05-19 14:13:19.872748	S116	6.412511958291214	3.0415521824072203	45
2026-05-19 14:13:19.872748	S116	6.409796830901634	3.0321215648885667	46
2026-05-19 14:13:19.872748	S116	6.411755368879823	3.014157496828133	47
2026-05-19 14:13:19.872748	S116	6.41236892814087	3.006900554383551	48
2026-05-19 14:13:19.872748	S116	6.406649616401365	2.9856775394497967	49
2026-05-19 14:13:19.872748	S116	6.40803187986865	2.97871359574438	50
2026-05-19 14:13:19.872748	S116	6.409692048237933	2.96554384856149	51
2026-05-19 14:13:19.872748	S116	6.407892255003358	2.9328215319260353	52
2026-05-19 14:13:19.872748	S116	6.408473400564246	2.9223108961748427	53
2026-05-19 14:13:19.872748	S116	6.408493606736785	2.8870030113576393	54
2026-05-19 14:13:19.872748	S116	6.411827319258985	2.8800170928689153	55
2026-05-19 14:13:19.872748	S116	6.4133337648634585	2.8779216840909934	56
2026-05-19 14:13:19.872748	S116	6.41595476406292	2.8760105054596723	57
2026-05-19 14:13:19.872748	S116	6.424639249359496	2.8576852568033555	58
2026-05-19 14:13:19.872748	S116	6.4401893185105195	2.8342525232164486	59
2026-05-19 14:13:19.872748	S116	6.4518529537357505	2.8204050865376207	60
2026-05-19 14:13:19.872748	S116	6.459266365361081	2.799813196089708	61
2026-05-19 14:13:19.872748	S116	6.457310984803258	2.790994814400415	62
2026-05-19 14:13:19.872748	S116	6.452369708092357	2.7850421223125013	63
2026-05-19 14:13:19.872748	S116	6.450986677878642	2.7814308984693117	64
2026-05-19 14:13:19.872748	S116	6.449654155895667	2.7709802227103912	65
2026-05-19 14:13:19.872748	S116	6.4460157858833265	2.751254943421838	66
2026-05-19 14:13:19.872748	S116	6.4486071702606775	2.743791751574156	67
2026-05-19 14:13:19.872748	S116	6.458525520123992	2.728272025827958	68
2026-05-19 14:13:19.872748	S116	6.457266445714334	2.716512469723355	69
2026-05-19 14:13:19.872748	S116	6.453536207425856	2.7093778596894564	70
2026-05-19 14:13:19.872748	S116	6.444312362442058	2.6912220188207496	71
2026-05-19 14:13:19.872748	S116	6.4421429271230775	2.6722552261475894	72
2026-05-19 14:13:19.872748	S116	6.444628285543086	2.6636662325480613	73
2026-05-19 14:13:19.872748	S116	6.456944455637746	2.644469056143989	74
2026-05-19 14:13:19.872748	S116	6.462329938049392	2.627955613354965	75
2026-05-19 14:13:19.872748	S116	6.466004874097848	2.6233855442023355	76
2026-05-19 14:13:19.872748	S121	6.474484688	3.294149195	1
2026-05-19 14:13:19.872748	S121	6.473551043665433	3.29503533472423	2
2026-05-19 14:13:19.872748	S121	6.468620909740463	3.2982122188377074	3
2026-05-19 14:13:19.872748	S121	6.46427864074641	3.300872568738685	4
2026-05-19 14:13:19.872748	S121	6.461162873168463	3.30513272647225	5
2026-05-19 14:13:19.872748	S121	6.459065680685751	3.3077365607099587	6
2026-05-19 14:13:19.872748	S121	6.452378008611597	3.313024367445412	7
2026-05-19 14:13:19.872748	S121	6.43893069242821	3.3179406913927583	8
2026-05-19 14:13:19.872748	S121	6.433940831405723	3.319927269064227	9
2026-05-19 14:13:19.872748	S121	6.432811755964513	3.319068431176726	10
2026-05-19 14:13:19.872748	S121	6.437342371	3.310792342	11
2026-05-19 14:13:19.872748	S122	6.474484688	3.294149195	1
2026-05-19 14:13:19.872748	S122	6.464445257871361	3.3011003803102597	2
2026-05-19 14:13:19.872748	S122	6.461348636245084	3.305334755480331	3
2026-05-19 14:13:19.872748	S122	6.458465568655328	3.3079572365272725	4
2026-05-19 14:13:19.872748	S122	6.449762960521042	3.3142536113504946	5
2026-05-19 14:13:19.872748	S122	6.432545468690307	3.3204553038454776	6
2026-05-19 14:13:19.872748	S122	6.4322864990606945	3.320939417466178	7
2026-05-19 14:13:19.872748	S122	6.431723919977344	3.321711430196558	8
2026-05-19 14:13:19.872748	S122	6.437229029714715	3.334211333720191	9
2026-05-19 14:13:19.872748	S122	6.435567565285879	3.3461887463602693	10
2026-05-19 14:13:19.872748	S122	6.439109066799276	3.356042081048116	11
2026-05-19 14:13:19.872748	S122	6.439064280470035	3.359173433733389	12
2026-05-19 14:13:19.872748	S122	6.432232669755621	3.3641286088483184	13
2026-05-19 14:13:19.872748	S122	6.4390793	3.3592365	14
2026-05-19 14:13:19.872748	S123	6.437342371	3.310792342	1
2026-05-19 14:13:19.872748	S123	6.437286089914082	3.2971994417888197	2
2026-05-19 14:13:19.872748	S123	6.431208105406398	3.2920349163277365	3
2026-05-19 14:13:19.872748	S123	6.428629041809714	3.277015963970058	4
2026-05-19 14:13:19.872748	S123	6.427831	3.258691	5
2026-05-19 14:13:19.872748	S124	6.4492081354225945	3.389713112398539	1
2026-05-19 14:13:19.872748	S124	6.451441065088071	3.3829119525782945	2
2026-05-19 14:13:19.872748	S124	6.453366833190138	3.3803861322979474	3
2026-05-19 14:13:19.872748	S124	6.456900041837391	3.3791850480808168	4
2026-05-19 14:13:19.872748	S124	6.462072672798968	3.379395913126663	5
2026-05-19 14:13:19.872748	S124	6.462734506635153	3.382478301866796	6
2026-05-19 14:13:19.872748	S124	6.490156416189616	3.4022407735552744	7
2026-05-19 14:13:19.872748	S124	6.521228500367762	3.428253364310632	8
2026-05-19 14:13:19.872748	S124	6.553069866619464	3.4509714376522256	9
2026-05-19 14:13:19.872748	S124	6.58944681990172	3.475611217092661	10
2026-05-19 14:13:19.872748	S124	6.601832	3.4862304	11
2026-05-19 14:13:19.872748	S125	6.449208123966997	3.389712483830607	1
2026-05-19 14:13:19.872748	S125	6.433772871148591	3.4010509386485523	2
2026-05-19 14:13:19.872748	S125	6.426261879500061	3.398339944598618	3
2026-05-19 14:13:19.872748	S125	6.4178816859334376	3.3989295877063057	4
2026-05-19 14:13:19.872748	S125	6.403028966072085	3.3989188190075765	5
2026-05-19 14:13:19.872748	S125	6.399357664288097	3.3985258428995735	6
2026-05-19 14:13:19.872748	S125	6.398639388657671	3.3982693814747336	7
2026-05-19 14:13:19.872748	S125	6.3983737849970055	3.397932413143593	8
2026-05-19 14:13:19.872748	S125	6.3984670778874175	3.3974331781763567	9
2026-05-19 14:13:19.872748	S125	6.398989076688025	3.3970315605724295	10
2026-05-19 14:13:19.872748	S125	6.401007351498663	3.396618723749384	11
2026-05-19 14:13:19.872748	S126	6.449208131096859	3.3897130724147204	1
2026-05-19 14:13:19.872748	S126	6.438821049750033	3.398971961242275	2
2026-05-19 14:13:19.872748	S126	6.4325293289408085	3.397594880817161	3
2026-05-19 14:13:19.872748	S126	6.432283950630482	3.397088152753828	4
2026-05-19 14:13:19.872748	S126	6.431037975990516	3.39462452107935	5
2026-05-19 14:13:19.872748	S126	6.431576010494137	3.392245842221233	6
2026-05-19 14:13:19.872748	S126	6.434719264699504	3.382051504257875	7
2026-05-19 14:13:19.872748	S126	6.43437945343406	3.380069271876112	8
2026-05-19 14:13:19.872748	S126	6.433105161188641	3.37652957119439	9
2026-05-19 14:13:19.872748	S126	6.431774233732313	3.372536788825408	10
2026-05-19 14:13:19.872748	S126	6.431122928806876	3.370582874049098	11
2026-05-19 14:13:19.872748	S126	6.431123457652282	3.369153149403982	12
2026-05-19 14:13:19.872748	S126	6.431356468354367	3.367677414957439	13
2026-05-19 14:13:19.872748	S126	6.43228851116271	3.365632098794687	14
2026-05-19 14:13:19.872748	S126	6.433712465453234	3.363768013178001	15
2026-05-19 14:13:19.872748	S126	6.438092045342704	3.358922820165902	16
2026-05-19 14:13:19.872748	S126	6.438569175216478	3.357640533630135	17
2026-05-19 14:13:19.872748	S126	6.438360430896702	3.354270803896606	18
2026-05-19 14:13:19.872748	S126	6.436183525847608	3.349529325775977	19
2026-05-19 14:13:19.872748	S126	6.435438010419836	3.34791901245199	20
2026-05-19 14:13:19.872748	S126	6.435955	3.343985	21
2026-05-19 14:13:19.872748	S126	6.4372570680636	3.338853544850284	22
2026-05-19 14:13:19.872748	S126	6.437405	3.337054	23
2026-05-19 14:13:19.872748	S126	6.436830024957669	3.33279452955396	24
2026-05-19 14:13:19.872748	S126	6.433792654161712	3.326403006958785	25
2026-05-19 14:13:19.872748	S126	6.43144474790226	3.322937050099593	26
2026-05-19 14:13:19.872748	S126	6.430829820072403	3.320197826130233	27
2026-05-19 14:13:19.872748	S126	6.435512057257997	3.313766733426001	28
2026-05-19 14:13:19.872748	S126	6.437035000900955	3.306203559456832	29
2026-05-19 14:13:19.872748	S126	6.437072269254279	3.303147554484212	30
2026-05-19 14:13:19.872748	S126	6.436923195840981	3.300948721638059	31
2026-05-19 14:13:19.872748	S126	6.43660544945724	3.298799517862232	32
2026-05-19 14:13:19.872748	S126	6.429566440034639	3.2916490105314	33
2026-05-19 14:13:19.872748	S126	6.429618598589352	3.287289870144581	34
2026-05-19 14:13:19.872748	S126	6.429003670759495	3.283674839872091	35
2026-05-19 14:13:19.872748	S126	6.427904254336418	3.280432493132848	36
2026-05-19 14:13:19.872748	S126	6.427811083453108	3.272680675641324	37
2026-05-19 14:13:19.872748	S126	6.42766201003981	3.267630813765836	38
2026-05-19 14:13:19.872748	S126	6.426998119802293	3.261582442901189	39
2026-05-19 14:13:19.872748	S126	6.426664550290312	3.252524553298327	40
2026-05-19 14:13:19.872748	S126	6.426552881465626	3.248607237065779	41
2026-05-19 14:13:19.872748	S126	6.4262228273509	3.245841069247123	42
2026-05-19 14:13:19.872748	S126	6.426065658724839	3.244913774353368	43
2026-05-19 14:13:19.872748	S126	6.425662041439185	3.244424281781221	44
2026-05-19 14:13:19.872748	S126	6.419878321268829	3.24373258202002	45
2026-05-19 14:13:19.872748	S126	6.41805005879578	3.243802899807445	46
2026-05-19 14:13:19.872748	S126	6.416292114110155	3.243662264232595	47
2026-05-19 14:13:19.872748	S126	6.416116319641592	3.24317003972062	48
2026-05-19 14:13:19.872748	S126	6.416327273003867	3.241271459460145	49
2026-05-19 14:13:19.872748	S126	6.416454019706714	3.238716683536926	50
2026-05-19 14:13:19.872748	S126	6.411965754757007	3.231065908038463	51
2026-05-19 14:13:19.872748	S126	6.406975693375611	3.223579895291138	52
2026-05-19 14:13:19.872748	S126	6.409264430958138	3.2173567406293677	53
2026-05-19 14:13:19.872748	S126	6.41442065080506	3.210849599584269	54
2026-05-19 14:13:19.872748	S126	6.415321223685508	3.211160141956838	55
2026-05-19 14:13:19.872748	S126	6.41578703724436	3.210694328397985	56
2026-05-19 14:13:19.872748	S126	6.415315978560096	3.207771162265023	57
2026-05-19 14:13:19.872748	S126	6.411943097751826	3.202870395278649	58
2026-05-19 14:13:19.872748	S126	6.408018452032906	3.198335880855896	59
2026-05-19 14:13:19.872748	S126	6.406538867782197	3.194838681717854	60
2026-05-19 14:13:19.872748	S126	6.414059427529772	3.186506896029426	61
2026-05-19 14:13:19.872748	S126	6.416600935757741	3.181751816119032	62
2026-05-19 14:13:19.872748	S126	6.416272999212198	3.179538244436606	63
2026-05-19 14:13:19.872748	S126	6.415289189575564	3.176176894844776	64
2026-05-19 14:13:19.872748	S126	6.410616093801556	3.17355340248042	65
2026-05-19 14:13:19.872748	S126	6.405844594348748	3.1698596509959014	66
2026-05-19 14:13:19.872748	S126	6.405402512179813	3.167661273383476	67
2026-05-19 14:13:19.872748	S126	6.406034526070403	3.1635328128022575	68
2026-05-19 14:13:19.872748	S126	6.408354259246833	3.1612356378799196	69
2026-05-19 14:13:19.872748	S126	6.412583713074822	3.156008797293792	70
2026-05-19 14:13:19.872748	S126	6.413239586165911	3.148958161564586	71
2026-05-19 14:13:19.872748	S126	6.411107998619872	3.139038081061866	72
2026-05-19 14:13:19.872748	S126	6.411740533509803	3.1318682392283876	73
2026-05-19 14:13:19.872748	S126	6.41232377232884	3.127402345473034	74
2026-05-19 14:13:19.872748	S126	6.413567522711456	3.123952999966821	75
2026-05-19 14:13:19.872748	S126	6.415343558831149	3.1151287291804635	76
2026-05-19 14:13:19.872748	S126	6.410698077937942	3.1046457358478916	77
2026-05-19 14:13:19.872748	S126	6.407828633164428	3.095586488777226	78
2026-05-19 14:13:19.872748	S126	6.409506616587763	3.0914576367414024	79
2026-05-19 14:13:19.872748	S126	6.412035461391685	3.08232262643776	80
2026-05-19 14:13:19.872748	S126	6.410675850284147	3.0755171732157294	81
2026-05-19 14:13:19.872748	S126	6.410219385476486	3.0681668932969184	82
2026-05-19 14:13:19.872748	S126	6.410698807270549	3.066750893634718	83
2026-05-19 14:13:19.872748	S126	6.416953284034209	3.061421279936694	84
2026-05-19 14:13:19.872748	S126	6.4166672044416	3.054531915720074	85
2026-05-19 14:13:19.872748	S126	6.415874199676249	3.050153878245607	86
2026-05-19 14:13:19.872748	S126	6.413145664162473	3.040965439330127	87
2026-05-19 14:13:19.872748	S126	6.410442572663591	3.0313372605821454	88
2026-05-19 14:13:19.872748	S126	6.411702828704332	3.020997709651777	89
2026-05-19 14:13:19.872748	S126	6.412930825161089	3.006657690248917	90
2026-05-19 14:13:19.872748	S126	6.407136772451542	2.9858331966701153	91
2026-05-19 14:13:19.872748	S126	6.408637212800576	2.979197107426244	92
2026-05-19 14:13:19.872748	S126	6.410058483781673	2.9654266874709467	93
2026-05-19 14:13:19.872748	S126	6.408213151911409	2.933620397751267	94
2026-05-19 14:13:19.872748	S126	6.408730458664676	2.922354008593367	95
2026-05-19 14:13:19.872748	S126	6.409058395210221	2.90964646745352	96
2026-05-19 14:13:19.872748	S126	6.408922036867496	2.886830561682122	97
2026-05-19 14:13:19.872748	S126	6.412055054618757	2.8799849778348556	98
2026-05-19 14:13:19.872748	S126	6.413513588082018	2.8780304103025722	99
2026-05-19 14:13:19.872748	S126	6.41595476406292	2.8760105054596723	100
2026-05-19 14:13:19.872748	S126	6.424034819479056	2.8576369838953095	101
2026-05-19 14:13:19.872748	S126	6.439654843270901	2.833185594405719	102
2026-05-19 14:13:19.872748	S126	6.451503190121583	2.8197506891227153	103
2026-05-19 14:13:19.872748	S126	6.457746727321793	2.799815528248449	104
2026-05-19 14:13:19.872748	S126	6.456478157892567	2.791787176712253	105
2026-05-19 14:13:19.872748	S126	6.451753515570637	2.785729861105501	106
2026-05-19 14:13:19.872748	S126	6.45019944030771	2.7812985146867266	107
2026-05-19 14:13:19.872748	S126	6.444768082624926	2.750939942494437	108
2026-05-19 14:13:19.872748	S126	6.4474444502276835	2.743059411911793	109
2026-05-19 14:13:19.872748	S126	6.453534151386544	2.735076844301304	110
2026-05-19 14:13:19.872748	S126	6.4575605534009926	2.728325453582707	111
2026-05-19 14:13:19.872748	S126	6.456554596665583	2.7168586561255976	112
2026-05-19 14:13:19.872748	S126	6.451383833322391	2.707214649311322	113
2026-05-19 14:13:19.872748	S126	6.446469234850715	2.7038499363420296	114
2026-05-19 14:13:19.872748	S126	6.4426813791823	2.691585858689828	115
2026-05-19 14:13:19.872748	S126	6.440120632078483	2.6724526460197495	116
2026-05-19 14:13:19.872748	S126	6.443143727181427	2.663031831897504	117
2026-05-19 14:13:19.872748	S126	6.455567596805501	2.645037526638773	118
2026-05-19 14:13:19.872748	S126	6.461353308980332	2.627239995573462	119
2026-05-19 14:13:19.872748	S126	6.466000568427495	2.623381052619242	120
2026-05-19 14:13:19.872748	S128	6.449208047244448	3.3897127900357433	1
2026-05-19 14:13:19.872748	S128	6.438572935317076	3.3978897547573017	2
2026-05-19 14:13:19.872748	S128	6.433144654387016	3.396733356508634	3
2026-05-19 14:13:19.872748	S128	6.431705742505199	3.394534485200914	4
2026-05-19 14:13:19.872748	S128	6.435524374355223	3.38066186993556	5
2026-05-19 14:13:19.872748	S128	6.433366095999907	3.376685122124744	6
2026-05-19 14:13:19.872748	S128	6.431081370593191	3.3713722537088104	7
2026-05-19 14:13:19.872748	S128	6.430774058252066	3.3688843210031942	8
2026-05-19 14:13:19.872748	S128	6.431184339614753	3.36749575335232	9
2026-05-19 14:13:19.872748	S128	6.431784953323722	3.3662025426306497	10
2026-05-19 14:13:19.872748	S128	6.43254241779938	3.3652027572085723	11
2026-05-19 14:13:19.872748	S128	6.4336224415737755	3.3639865701318974	12
2026-05-19 14:13:19.872748	S128	6.4348346448196665	3.3629146276216098	13
2026-05-19 14:13:19.872748	S128	6.436363080765332	3.3616008244369153	14
2026-05-19 14:13:19.872748	S128	6.437676478675207	3.3604843286442487	15
2026-05-19 14:13:19.872748	S128	6.439064261925379	3.359173314896516	16
2026-05-19 14:13:19.872748	S129	6.449207443011608	3.389713363422642	1
2026-05-19 14:13:19.872748	S129	6.438368685397062	3.397024980225046	2
2026-05-19 14:13:19.872748	S129	6.432112345460199	3.3943843699884138	3
2026-05-19 14:13:19.872748	S129	6.433664828762231	3.3863233418099252	4
2026-05-19 14:13:19.872748	S129	6.435113421178119	3.3807906420568203	5
2026-05-19 14:13:19.872748	S129	6.432749313530195	3.376980912818123	6
2026-05-19 14:13:19.872748	S131	6.441002654802053	3.348632701587175	1
2026-05-19 14:13:19.872748	S131	6.442618578585259	3.34927464391201	2
2026-05-19 14:13:19.872748	S132	6.446059237	3.349851834	1
2026-05-19 14:13:19.872748	S132	6.44263934	3.349289318	2
2026-05-19 14:13:19.872748	S135	6.448196836028655	3.351421830308873	1
2026-05-19 14:13:19.872748	S135	6.448418195451012	3.350890567695216	2
2026-05-19 14:13:19.872748	S136	6.449208204922252	3.389712743553326	1
2026-05-19 14:13:19.872748	S136	6.446050146992505	3.3942581268569016	2
2026-05-19 14:13:19.872748	S136	6.44249752057788	3.3987175975131416	3
2026-05-19 14:13:19.872748	S136	6.439631156206873	3.401889597480791	4
2026-05-19 14:13:19.872748	S136	6.439517184709804	3.402163936395179	5
2026-05-19 14:13:19.872748	S136	6.43956619114654	3.4023700250430324	6
2026-05-19 14:13:19.872748	S136	6.439690414994142	3.4024701540541864	7
2026-05-19 14:13:19.872748	S136	6.439814638841744	3.4025702830653404	8
2026-05-19 14:13:19.872748	S136	6.4403115461938105	3.402930364118834	9
2026-05-19 14:13:19.872748	S136	6.441201659355251	3.4037304377365727	10
2026-05-19 14:13:19.872748	S136	6.442051881829567	3.4048950851861615	11
2026-05-19 14:13:19.872748	S136	6.442291225253339	3.4055317016095104	12
2026-05-19 14:13:19.872748	S136	6.442495224923931	3.406946227363831	13
2026-05-19 14:13:19.872748	S136	6.44234707427862	3.408779120312196	14
2026-05-19 14:13:19.872748	S136	6.4413304584378865	3.411179341169589	15
2026-05-19 14:13:19.872748	S136	6.439459062471519	3.4148595839706046	16
2026-05-19 14:13:19.872748	S136	6.438663546910677	3.4182381518224343	17
2026-05-19 14:13:19.872748	S136	6.439796407179965	3.4216431970981995	18
2026-05-19 14:13:19.872748	S136	6.441035265795154	3.4248318303276712	19
2026-05-19 14:13:19.872748	S136	6.442095819404855	3.427175929330542	20
2026-05-19 14:13:19.872748	S136	6.4419228367215435	3.4303638012840194	21
2026-05-19 14:13:19.872748	S136	6.442009341133054	3.4357137863173786	22
2026-05-19 14:13:19.872748	S136	6.44140278483402	3.437155764343044	23
2026-05-19 14:13:19.872748	S136	6.440149510298384	3.4398362780404264	24
2026-05-19 14:13:19.872748	S136	6.437915388074416	3.443231555584459	25
2026-05-19 14:13:19.872748	S136	6.437778888335049	3.445218159043621	26
2026-05-19 14:13:19.872748	S136	6.438740995632407	3.448859884754193	27
2026-05-19 14:13:19.872748	S136	6.440461064426022	3.451626442432888	28
2026-05-19 14:13:19.872748	S136	6.440944070228081	3.4522227405141184	29
2026-05-19 14:13:19.872748	S136	6.443862414730295	3.45266926359111	30
2026-05-19 14:13:19.872748	S136	6.449338650123927	3.4524984834739842	31
2026-05-19 14:13:19.872748	S136	6.450021770598346	3.452667296356809	32
2026-05-19 14:13:19.872748	S136	6.450372048355996	3.4531888808856683	33
2026-05-19 14:13:19.872748	S136	6.4508249065333265	3.454190651557202	34
2026-05-19 14:13:19.872748	S136	6.450871575192487	3.455772308693896	35
2026-05-19 14:13:19.872748	S136	6.450519756958613	3.457047310268364	36
2026-05-19 14:13:19.872748	S136	6.449817195434555	3.45872662037407	37
2026-05-19 14:13:19.872748	S136	6.4490243779130765	3.460774218852313	38
2026-05-19 14:13:19.872748	S136	6.448724925200962	3.464109564303319	39
2026-05-19 14:13:19.872748	S136	6.4494749402441265	3.4680942602393117	40
2026-05-19 14:13:19.872748	S136	6.450683539517145	3.468592186996923	41
2026-05-19 14:13:19.872748	S136	6.451781480025574	3.4684384539145245	42
2026-05-19 14:13:19.872748	S136	6.455197088118971	3.4676500456924564	43
2026-05-19 14:13:19.872748	S136	6.456713886279312	3.4669846704134315	44
2026-05-19 14:13:19.872748	S136	6.458746121688787	3.4667861499823065	45
2026-05-19 14:13:19.872748	S136	6.459496364558088	3.4669228528818827	46
2026-05-19 14:13:19.872748	S136	6.463287666545479	3.468771356891279	47
2026-05-19 14:13:19.872748	S136	6.483828456285103	3.4791096534679777	48
2026-05-19 14:13:19.872748	S136	6.501751347871943	3.5209078150969573	49
2026-05-19 14:13:19.872748	S136	6.509032234616332	3.557179818742583	50
2026-05-19 14:13:19.872748	S136	6.520174848209958	3.5992819734831354	51
2026-05-19 14:13:19.872748	S136	6.512190230720236	3.6152370992586396	52
2026-05-19 14:13:19.872748	S138	6.45040017450207	3.351582550566885	1
2026-05-19 14:13:19.872748	S138	6.450387387674674	3.351166978676504	2
2026-05-19 14:13:19.872748	S140	6.435336103180063	3.343401869491687	1
2026-05-19 14:13:19.872748	S140	6.43687156597025	3.344153932899125	2
2026-05-19 14:13:19.872748	S142	6.446357951829157	3.349967622024593	1
2026-05-19 14:13:19.872748	S142	6.446066939630768	3.3504457669607746	2
2026-05-19 14:13:19.872748	S144	6.4590668022350854	3.307735846940261	1
2026-05-19 14:13:19.872748	S144	6.453047768931935	3.3127111454147666	2
2026-05-19 14:13:19.872748	S144	6.432309690110181	3.320459574526552	3
2026-05-19 14:13:19.872748	S144	6.4382301264844735	3.3047851231092977	4
2026-05-19 14:13:19.872748	S144	6.437337024123646	3.2983289814638823	5
2026-05-19 14:13:19.872748	S144	6.430412595481995	3.291841436739169	6
2026-05-19 14:13:19.872748	S144	6.428514132883409	3.2815324096476104	7
2026-05-19 14:13:19.872748	S144	6.426046878441184	3.246329820881982	8
2026-05-19 14:13:19.872748	S144	6.429448358626601	3.235578729662734	9
2026-05-19 14:13:19.872748	S144	6.43326142368101	3.2282634183255965	10
2026-05-19 14:13:19.872748	S144	6.436028054081618	3.2202456519385407	11
2026-05-19 14:13:19.872748	S144	6.4349916973920145	3.21222094984644	12
2026-05-19 14:13:19.872748	S144	6.4341944103398845	3.2050595725933704	13
2026-05-19 14:13:19.872748	S144	6.4372642785559435	3.195381585688864	14
2026-05-19 14:13:19.872748	S144	6.43497874091122	3.1897964932556704	15
2026-05-19 14:13:19.872748	S144	6.434280117812456	3.1874897231375456	16
2026-05-19 14:13:19.872748	S144	6.435156845742	3.184856733715378	17
2026-05-19 14:13:19.872748	S144	6.438504227835423	3.178323249636776	18
2026-05-19 14:13:19.872748	S144	6.439972951567899	3.1754834083642933	19
2026-05-19 14:13:19.872748	S144	6.441193588891046	3.1727323614509686	20
2026-05-19 14:13:19.872748	S144	6.441077341547398	3.168777071899086	21
2026-05-19 14:13:19.872748	S144	6.439720362532441	3.1665269747928164	22
2026-05-19 14:13:19.872748	S144	6.437896179811801	3.164870027719502	23
2026-05-19 14:13:19.872748	S144	6.4293480168512005	3.161739029546524	24
2026-05-19 14:13:19.872748	S144	6.42708557743256	3.1598732547167927	25
2026-05-19 14:13:19.872748	S144	6.424882042167567	3.1560191354376173	26
2026-05-19 14:13:19.872748	S144	6.423738917675962	3.1526299015946506	27
2026-05-19 14:13:19.872748	S144	6.420939990137498	3.149760565379097	28
2026-05-19 14:13:19.872748	S144	6.420745602878942	3.14729342821191	29
2026-05-19 14:13:19.872748	S144	6.421615846186434	3.1451382610307235	30
2026-05-19 14:13:19.872748	S144	6.422638858090394	3.1437432685611952	31
2026-05-19 14:13:19.872748	S144	6.424975119284884	3.141458923390715	32
2026-05-19 14:13:19.872748	S144	6.428145900111822	3.1349121352745613	33
2026-05-19 14:13:19.872748	S144	6.427610692681796	3.1300209719780128	34
2026-05-19 14:13:19.872748	S144	6.426448439913088	3.119656118248983	35
2026-05-19 14:13:19.872748	S144	6.427252000210899	3.1159692483787182	36
2026-05-19 14:13:19.872748	S144	6.427366902666819	3.112282080846825	37
2026-05-19 14:13:19.872748	S144	6.425508642567451	3.1093544512542053	38
2026-05-19 14:13:19.872748	S144	6.421990966542964	3.1075275611294444	39
2026-05-19 14:13:19.872748	S144	6.416177966973166	3.107116623591807	40
2026-05-19 14:13:19.872748	S144	6.410054944291247	3.1058338031690766	41
2026-05-19 14:13:19.872748	S144	6.4072274477246935	3.1013998309408493	42
2026-05-19 14:13:19.872748	S144	6.406264267306227	3.094804577745947	43
2026-05-19 14:13:19.872748	S144	6.409858520690349	3.0822872911037678	44
2026-05-19 14:13:19.872748	S144	6.409540974572764	3.0673317414569397	45
2026-05-19 14:13:19.872748	S144	6.410374666391732	3.0623464996904204	46
2026-05-19 14:13:19.872748	S144	6.414721941561936	3.051715055378139	47
2026-05-19 14:13:19.872748	S144	6.413729110889079	3.0479952157908485	48
2026-05-19 14:13:19.872748	S144	6.409224605614227	3.036898213836537	49
2026-05-19 14:13:19.872748	S144	6.405917177824513	3.026736637051407	50
2026-05-19 14:13:19.872748	S144	6.405206501077533	3.025041216661567	51
2026-05-19 14:13:19.872748	S144	6.405239843183281	3.024008833249482	52
2026-05-19 14:13:19.872748	S144	6.406594803375384	3.0177777346514176	53
2026-05-19 14:13:19.872748	S144	6.4111589610039985	3.0115397858750015	54
2026-05-19 14:13:19.872748	S144	6.411395064853153	3.0074952409685523	55
2026-05-19 14:13:19.872748	S144	6.405788677768186	2.9856568866621416	56
2026-05-19 14:13:19.872748	S144	6.407045197999523	2.97899623409387	57
2026-05-19 14:13:19.872748	S144	6.408877895636543	2.9655888535810817	58
2026-05-19 14:13:19.872748	S144	6.407957680818782	2.953234938227382	59
2026-05-19 14:13:19.872748	S144	6.407797019564583	2.9423050638166757	60
2026-05-19 14:13:19.872748	S144	6.407383959615686	2.9335830661980253	61
2026-05-19 14:13:19.872748	S144	6.4077731820107005	2.921599823213569	62
2026-05-19 14:13:19.872748	S144	6.406592105794915	2.898810750980884	63
2026-05-19 14:13:19.872748	S144	6.407406281284688	2.8866112461523246	64
2026-05-19 14:13:19.872748	S144	6.408045858744133	2.884060352224278	65
2026-05-19 14:13:19.872748	S144	6.414208329261139	2.875828066632275	66
2026-05-19 14:13:19.872748	S144	6.41838718070149	2.8660648225610075	67
2026-05-19 14:13:19.872748	S144	6.4231538644120505	2.8555185981304163	68
2026-05-19 14:13:19.872748	S144	6.426353817218086	2.850434867589854	69
2026-05-19 14:13:19.872748	S144	6.439063195541099	2.8320277104967193	70
2026-05-19 14:13:19.872748	S144	6.450269473874904	2.81881078061625	71
2026-05-19 14:13:19.872748	S144	6.45440341632035	2.807563830195525	72
2026-05-19 14:13:19.872748	S144	6.455652382889639	2.799331777242436	73
2026-05-19 14:13:19.872748	S144	6.453862435780465	2.7931598129061825	74
2026-05-19 14:13:19.872748	S144	6.448569106621335	2.7833930810137986	75
2026-05-19 14:13:19.872748	S144	6.443121075623324	2.7497355998113733	76
2026-05-19 14:13:19.872748	S144	6.445899524540508	2.742216392185753	77
2026-05-19 14:13:19.872748	S144	6.451070910578906	2.73617632500698	78
2026-05-19 14:13:19.872748	S144	6.456120762575694	2.72802144129912	79
2026-05-19 14:13:19.872748	S144	6.455388317218592	2.7175419370011014	80
2026-05-19 14:13:19.872748	S144	6.450031985772	2.7082451392772384	81
2026-05-19 14:13:19.872748	S144	6.4472791217291245	2.706729443309257	82
2026-05-19 14:13:19.872748	S144	6.447039531909624	2.7065856763532565	83
2026-05-19 14:13:19.872748	S144	6.446816015105199	2.7065227860957464	84
2026-05-19 14:13:19.872748	S144	6.446484571452153	2.706607622503114	85
2026-05-19 14:13:19.872748	S144	6.446178844702672	2.706711869319463	86
2026-05-19 14:13:19.872748	S144	6.445212259346974	2.7068955274947655	87
2026-05-19 14:13:19.872748	S144	6.445076529112484	2.706949547333565	88
2026-05-19 14:13:19.872748	S144	6.444979356546185	2.7070872696031714	89
2026-05-19 14:13:19.872748	S144	6.444911730937335	2.7073290639538925	90
2026-05-19 14:13:19.872748	S144	6.444710753446131	2.707960851256587	91
2026-05-19 14:13:19.872748	S144	6.4448563011833855	2.707343174956904	92
2026-05-19 14:13:19.872748	S144	6.444977226448856	2.706943554442404	93
2026-05-19 14:13:19.872748	S144	6.445106566851948	2.706855015905937	94
2026-05-19 14:13:19.872748	S144	6.445270463663974	2.7068017358441665	95
2026-05-19 14:13:19.872748	S144	6.446353253271894	2.7066261055482244	96
2026-05-19 14:13:19.872748	S144	6.449032010901362	2.7056627600537695	97
2026-05-19 14:13:19.872748	S144	6.449257765078823	2.7043788493037866	98
2026-05-19 14:13:19.872748	S144	6.445316830434244	2.6907990958325883	99
2026-05-19 14:13:19.872748	S144	6.443077064182987	2.672308668083872	100
2026-05-19 14:13:19.872748	S144	6.445507892901368	2.6640536458694726	101
2026-05-19 14:13:19.872748	S144	6.457325458170359	2.6445623636921596	102
2026-05-19 14:13:19.872748	S144	6.462716872282023	2.6282654644694503	103
2026-05-19 14:13:19.872748	S144	6.465995687572757	2.62338128823194	104
2026-05-19 14:13:19.872748	S148	6.407551828228942	3.261648271553033	1
2026-05-19 14:13:19.872748	S148	6.4123980184837635	3.247655434719591	2
2026-05-19 14:13:19.872748	S148	6.417631045265343	3.2381120812881194	3
2026-05-19 14:13:19.872748	S148	6.417414091167817	3.2365837449062225	4
2026-05-19 14:13:19.872748	S148	6.407223917048471	3.2237268041425375	5
2026-05-19 14:13:19.872748	S148	6.408614832281238	3.2104669740911254	6
2026-05-19 14:13:19.872748	S148	6.406651958343591	3.205551786969208	7
2026-05-19 14:13:19.872748	S148	6.414245767461447	3.212965728872917	8
2026-05-19 14:13:19.872748	S148	6.415927806687773	3.210824404637061	9
2026-05-19 14:13:19.872748	S148	6.415971707178945	3.2074984715131776	10
2026-05-19 14:13:19.872748	S148	6.416346762494447	3.199419475461721	11
2026-05-19 14:13:19.872748	S148	6.417367093332628	3.1990057328668655	12
2026-05-19 14:13:19.872748	S148	6.4185382067447	3.198753850037465	13
2026-05-19 14:13:19.872748	S148	6.419539060415695	3.1993084065809607	14
2026-05-19 14:13:19.872748	S148	6.421862519723986	3.1989498692047227	15
2026-05-19 14:13:19.872748	S148	6.425125650963817	3.199341777141711	16
2026-05-19 14:13:19.872748	S148	6.426958699751105	3.1994380185557665	17
2026-05-19 14:13:19.872748	S148	6.430644201964959	3.199255843590292	18
2026-05-19 14:13:19.872748	S148	6.431818591734833	3.199198168707534	19
2026-05-19 14:13:19.872748	S148	6.43273181328109	3.199359806428408	20
2026-05-19 14:13:19.872748	S148	6.433438748806801	3.1997841869184964	21
2026-05-19 14:13:19.872748	S148	6.434339149052009	3.199862008680047	22
2026-05-19 14:13:19.872748	S148	6.435235636383625	3.199637886847143	23
2026-05-19 14:13:19.872748	S148	6.435795940965884	3.199541834633042	24
2026-05-19 14:13:19.872748	S148	6.436292210738742	3.199493808525991	25
2026-05-19 14:13:19.872748	S148	6.436724445702199	3.199509817228341	26
2026-05-19 14:13:19.872748	S148	6.437172448732188	3.199729685962439	27
2026-05-19 14:13:19.872748	S148	6.437481633442951	3.200908287509451	28
2026-05-19 14:13:19.872748	S148	6.437750730276349	3.201913346068144	29
2026-05-19 14:13:19.872748	S148	6.437775849379801	3.202000121152798	30
2026-05-19 14:13:19.872748	S148	6.437928089527067	3.202024113888362	31
2026-05-19 14:13:19.872748	S148	6.438179991338727	3.202069670598982	32
2026-05-19 14:13:19.872748	S148	6.438353316713476	3.202058903121032	33
2026-05-19 14:13:19.872748	S148	6.438582941520941	3.202044064682965	34
2026-05-19 14:13:19.872748	S148	6.438634797642549	3.202036314949733	35
2026-05-19 14:13:19.872748	S148	6.438649159270327	3.202039905356677	36
2026-05-19 14:13:19.872748	S148	6.439096485164126	3.202198301311318	37
2026-05-19 14:13:19.872748	S148	6.439329628330236	3.202503799253118	38
2026-05-19 14:13:19.872748	S148	6.439444860010037	3.202661907837032	39
2026-05-19 14:13:19.872748	S148	6.439503815753192	3.202744981838749	40
2026-05-19 14:13:19.872748	S148	6.439535973431276	3.202761060677791	41
2026-05-19 14:13:19.872748	S148	6.43958688975491	3.202806617388411	42
2026-05-19 14:13:19.872748	S148	6.439673585476046	3.202875950657815	43
2026-05-19 14:13:19.872748	S148	6.439782976171497	3.202975839514171	44
2026-05-19 14:13:19.872748	S148	6.439859522026505	3.203059773057337	45
2026-05-19 14:13:19.872748	S148	6.439907346520113	3.203113913993497	46
2026-05-19 14:13:19.872748	S148	6.440017658768764	3.203237227199949	47
2026-05-19 14:13:19.872748	S148	6.440049067511061	3.203253334768289	48
2026-05-19 14:13:19.872748	S148	6.440090881864421	3.203245732158587	49
2026-05-19 14:13:19.872748	S148	6.440241033406033	3.203238129548885	50
2026-05-19 14:13:19.872748	S148	6.440290040379391	3.203245244736249	51
2026-05-19 14:13:19.872748	S148	6.440395633385391	3.203231298490174	52
2026-05-19 14:13:19.872748	S148	6.440503218712259	3.203251221698853	53
2026-05-19 14:13:19.872748	S148	6.440680535269504	3.203299037399683	54
2026-05-19 14:13:19.872748	S148	6.440841913259805	3.203332906854437	55
2026-05-19 14:13:19.872748	S148	6.440997314287503	3.203358807025721	56
2026-05-19 14:13:19.872748	S148	6.441130799785653	3.203386699517871	57
2026-05-19 14:13:19.872748	S148	6.441178615486484	3.203392676480475	58
2026-05-19 14:13:19.872748	S148	6.441268060756738	3.203600712149039	59
2026-05-19 14:13:19.872748	S148	6.441369527365509	3.203789150136757	60
2026-05-19 14:13:19.872748	S148	6.441414821457691	3.203948121293879	61
2026-05-19 14:13:19.872748	S148	6.441714184254777	3.204284140759996	62
2026-05-19 14:13:19.872748	S148	6.442053258443313	3.204772896347075	63
2026-05-19 14:13:19.872748	S148	6.442248760678145	3.205050876087226	64
2026-05-19 14:13:19.872748	S148	6.442374004297332	3.205310527492861	65
2026-05-19 14:13:19.872748	S148	6.442386223187009	3.205686258350428	66
2026-05-19 14:13:19.872748	S148	6.442395387354266	3.205793173635101	67
2026-05-19 14:13:19.872748	S148	6.44230374568169	3.206031441983802	68
2026-05-19 14:13:19.872748	S148	6.442205994564274	3.206275819777342	69
2026-05-19 14:13:19.872748	S148	6.442025765941538	3.206556854239912	70
2026-05-19 14:13:19.872748	S148	6.44193717899138	3.206682097859101	71
2026-05-19 14:13:19.872748	S148	6.441900522322349	3.206819560367967	72
2026-05-19 14:13:19.872748	S148	6.441885829688987	3.206950397050636	73
2026-05-19 14:13:19.872748	S148	6.441954138394951	3.206969564269626	74
2026-05-19 14:13:19.872748	S148	6.442053848715006	3.207009122147109	75
2026-05-19 14:13:19.872748	S148	6.442169667655271	3.207031959684626	76
2026-05-19 14:13:19.872748	S148	6.442796068684314	3.207031959684626	77
2026-05-19 14:13:19.872748	S148	6.443091325419357	3.207035222189985	78
2026-05-19 14:13:19.872748	S148	6.443469776041071	3.206911246986321	79
2026-05-19 14:13:19.872748	S148	6.443779603272752	3.206503086279182	80
2026-05-19 14:13:19.872748	S148	6.443884385735166	3.206527535520412	81
2026-05-19 14:13:19.872748	S148	6.444041559428788	3.206611361490344	82
2026-05-19 14:13:19.872748	S148	6.444432747288471	3.206754564188978	83
2026-05-19 14:13:19.872748	S148	6.444706080161613	3.206804225996699	84
2026-05-19 14:13:19.872748	S148	6.445215594905838	3.206851403287831	85
2026-05-19 14:13:19.872748	S148	6.445489223194404	3.206874991933397	86
2026-05-19 14:13:19.872748	S148	6.446017608855081	3.20701180607768	87
2026-05-19 14:13:19.872748	S148	6.446220471206949	3.207073136556152	88
2026-05-19 14:13:19.872748	S148	6.446451639933496	3.207058983368812	89
2026-05-19 14:13:19.872748	S148	6.446734703680288	3.207021241535907	90
2026-05-19 14:13:19.872748	S148	6.447691481869566	3.206286535856859	91
2026-05-19 14:13:19.872748	S148	6.451306611466339	3.204691272048581	92
2026-05-19 14:13:19.872748	S148	6.453176016321364	3.204245472039803	93
2026-05-19 14:13:19.872748	S149	6.418094084	3.362453877	1
2026-05-19 14:13:19.872748	S149	6.417626165505482	3.3588530258308253	2
2026-05-19 14:13:19.872748	S154	6.449208123966997	3.389712483830607	1
2026-05-19 14:13:19.872748	S154	6.438602925286801	3.3981149241239166	2
2026-05-19 14:13:19.872748	S154	6.434195277701036	3.4013952654887305	3
2026-05-19 14:13:19.872748	S154	6.431533922693276	3.4012483838235177	4
2026-05-19 14:13:19.872748	S154	6.426949556511204	3.399752068931498	5
2026-05-19 14:13:19.872748	S154	6.426259859919696	3.3983410982028346	6
2026-05-19 14:13:19.872748	S155	6.56021613	3.600195878	1
2026-05-19 14:13:19.872748	S155	6.536065959390483	3.5675395919020985	2
2026-05-19 14:13:19.872748	S155	6.520288374669558	3.5366968042112807	3
2026-05-19 14:13:19.872748	S155	6.4903140117301135	3.4736293018554854	4
2026-05-19 14:13:19.872748	S155	6.467824057139126	3.388769442375831	5
2026-05-19 14:13:19.872748	S155	6.462734251023601	3.3824784268241403	6
2026-05-19 14:13:19.872748	S155	6.46190160775643	3.379515026606465	7
2026-05-19 14:13:19.872748	S155	6.456943156351156	3.379461217800876	8
2026-05-19 14:13:19.872748	S155	6.453528671372961	3.3806238083943745	9
2026-05-19 14:13:19.872748	S155	6.451701144408234	3.3829830242539716	10
2026-05-19 14:13:19.872748	S155	6.4492081354225945	3.389713112398539	11
2026-05-19 14:13:19.872748	S156	6.466001455685301	2.6234022025985553	1
2026-05-19 14:13:19.872748	S156	6.464218875874991	2.6263465944822286	2
2026-05-19 14:13:19.872748	S156	6.463059293757311	2.628491041230234	3
2026-05-19 14:13:19.872748	S156	6.457743249197392	2.6447500483373574	4
2026-05-19 14:13:19.872748	S156	6.446079239727396	2.6642851951660305	5
2026-05-19 14:13:19.872748	S156	6.44373277904937	2.6722846212281297	6
2026-05-19 14:13:19.872748	S156	6.446283016088003	2.6908417301740712	7
2026-05-19 14:13:19.872748	S156	6.453882562516327	2.7074587881646437	8
2026-05-19 14:13:19.872748	S156	6.458103472282417	2.716034684737494	9
2026-05-19 14:13:19.872748	S156	6.4592412206635	2.7283578809825144	10
2026-05-19 14:13:19.872748	S156	6.452705096021354	2.7393801378924962	11
2026-05-19 14:13:19.872748	S156	6.449512839059565	2.7443167338416288	12
2026-05-19 14:13:19.872748	S156	6.447476486252853	2.751334377543344	13
2026-05-19 14:13:19.872748	S156	6.451796401198223	2.7812704812797335	14
2026-05-19 14:13:19.872748	S156	6.453007033807104	2.7846795599949985	15
2026-05-19 14:13:19.872748	S156	6.4580452312373104	2.790553861730956	16
2026-05-19 14:13:19.872748	S156	6.460235613878439	2.7996851404267886	17
2026-05-19 14:13:19.872748	S156	6.452534991814304	2.8202829011129324	18
2026-05-19 14:13:19.872748	S156	6.429105356812087	2.8518438313936656	19
2026-05-19 14:13:19.872748	S156	6.419559539927235	2.860755439101183	20
2026-05-19 14:13:19.872748	S156	6.4157397710867485	2.870297827612603	21
2026-05-19 14:13:19.872748	S156	6.413811834692396	2.874444425608715	22
2026-05-19 14:13:19.872748	S156	6.410709463834635	2.8779934979075392	23
2026-05-19 14:13:19.872748	S156	6.406916104022088	2.8836168963792943	24
2026-05-19 14:13:19.872748	S156	6.406589577321313	2.8864116891401466	25
2026-05-19 14:13:19.872748	S156	6.405434624462501	2.8993000344342477	26
2026-05-19 14:13:19.872748	S156	6.407128563554494	2.9216486366928223	27
2026-05-19 14:13:19.872748	S156	6.40592444381091	2.927466605524174	28
2026-05-19 14:13:19.872748	S156	6.401707440793121	2.938927279730585	29
2026-05-19 14:13:19.872748	S156	6.402386268505822	2.944588979865898	30
2026-05-19 14:13:19.872748	S156	6.407014838368795	2.953395692783033	31
2026-05-19 14:13:19.872748	S156	6.407637553745715	2.9570101247395257	32
2026-05-19 14:13:19.872748	S156	6.408167193652339	2.9657222091477564	33
2026-05-19 14:13:19.872748	S156	6.4050602878331375	2.98572001801719	34
2026-05-19 14:13:19.872748	S156	6.410724022523183	3.0079984112140608	35
2026-05-19 14:13:19.872748	S156	6.410671620497084	3.0098789248071114	36
2026-05-19 14:13:19.872748	S156	6.4090764636667785	3.012381778592669	37
2026-05-19 14:13:19.872748	S156	6.405561874440302	3.01723537222756	38
2026-05-19 14:13:19.872748	S156	6.404369815733446	3.0240365699480662	39
2026-05-19 14:13:19.872748	S156	6.405517837687043	3.0279391145382135	40
2026-05-19 14:13:19.872748	S156	6.407232606363692	3.033336600588626	41
2026-05-19 14:13:19.872748	S156	6.407660179945182	3.036952503234346	42
2026-05-19 14:13:19.872748	S156	6.410298341365536	3.0432344587902733	43
2026-05-19 14:13:19.872748	S156	6.412990372564757	3.047367978577185	44
2026-05-19 14:13:19.872748	S156	6.4138824792410105	3.0515441417827844	45
2026-05-19 14:13:19.872748	S156	6.410610468055509	3.055017170930711	46
2026-05-19 14:13:19.872748	S156	6.4087871606377576	3.0671719170974825	47
2026-05-19 14:13:19.872748	S156	6.40906401196311	3.0800078682151195	48
2026-05-19 14:13:19.872748	S156	6.407591335535415	3.088346244955261	49
2026-05-19 14:13:19.872748	S156	6.406311957805364	3.09218813796069	50
2026-05-19 14:13:19.872748	S156	6.405432870707099	3.0938853545545513	51
2026-05-19 14:13:19.872748	S156	6.406215726662353	3.1017879701566073	52
2026-05-19 14:13:19.872748	S156	6.409201513530945	3.108432408969435	53
2026-05-19 14:13:19.872748	S156	6.417536293357671	3.1085808673872464	54
2026-05-19 14:13:19.872748	S156	6.422999867185503	3.109698145025021	55
2026-05-19 14:13:19.872748	S156	6.426143740573803	3.111246279583753	56
2026-05-19 14:13:19.872748	S156	6.427110016360345	3.1132329514437345	57
2026-05-19 14:13:19.872748	S156	6.4260803922622785	3.1174822798533626	58
2026-05-19 14:13:19.872748	S156	6.425537827284444	3.122518095434998	59
2026-05-19 14:13:19.872748	S156	6.4267370724532356	3.130906587102885	60
2026-05-19 14:13:19.872748	S156	6.426739495916827	3.134507737202327	61
2026-05-19 14:13:19.872748	S156	6.425563283576583	3.1375590477338946	62
2026-05-19 14:13:19.872748	S156	6.423993401023148	3.140223310760444	63
2026-05-19 14:13:19.872748	S156	6.421972571105724	3.142259503895948	64
2026-05-19 14:13:19.872748	S156	6.420277757257393	3.1453432266097776	65
2026-05-19 14:13:19.872748	S156	6.419726948123028	3.147588500503531	66
2026-05-19 14:13:19.872748	S156	6.420402530726491	3.1501045601061435	67
2026-05-19 14:13:19.872748	S156	6.42364694114795	3.1538297697275084	68
2026-05-19 14:13:19.872748	S156	6.425001547466238	3.1577791243086892	69
2026-05-19 14:13:19.872748	S156	6.427165834729578	3.160675544873399	70
2026-05-19 14:13:19.872748	S156	6.42922937549146	3.1621982563322035	71
2026-05-19 14:13:19.872748	S156	6.433110527813	3.1634660767387004	72
2026-05-19 14:13:19.872748	S156	6.437184854773932	3.1654163366661976	73
2026-05-19 14:13:19.872748	S156	6.43923671072104	3.1669491267279	74
2026-05-19 14:13:19.872748	S156	6.440557458696489	3.1686699627023813	75
2026-05-19 14:13:19.872748	S156	6.4409752415151615	3.171795876143392	76
2026-05-19 14:13:19.872748	S156	6.4402378417328805	3.174024888513543	77
2026-05-19 14:13:19.872748	S156	6.436653895046348	3.1808835586816144	78
2026-05-19 14:13:19.872748	S156	6.434831493491728	3.1839246667385055	79
2026-05-19 14:13:19.872748	S156	6.43394094556988	3.185923344442969	80
2026-05-19 14:13:19.872748	S156	6.4336494736175105	3.1875506156275506	81
2026-05-19 14:13:19.872748	S156	6.435240718824284	3.192485535342886	82
2026-05-19 14:13:19.872748	S156	6.436649317958782	3.195436171926019	83
2026-05-19 14:13:19.872748	S156	6.435177497141041	3.2000003553137617	84
2026-05-19 14:13:19.872748	S156	6.433674310079965	3.205593443711024	85
2026-05-19 14:13:19.872748	S156	6.435489799941408	3.220151156433076	86
2026-05-19 14:13:19.872748	S156	6.434941202765501	3.2292242813069834	87
2026-05-19 14:13:19.872748	S156	6.437027196618345	3.236689038594278	88
2026-05-19 14:13:19.872748	S156	6.434990856097727	3.2399024724104777	89
2026-05-19 14:13:19.872748	S156	6.433469324630323	3.2412774060689173	90
2026-05-19 14:13:19.872748	S156	6.429028910835299	3.2428710791723745	91
2026-05-19 14:13:19.872748	S156	6.426219299628642	3.245723597567263	92
2026-05-19 14:13:19.872748	S156	6.429857840469339	3.2883887332324093	93
2026-05-19 14:13:19.872748	S156	6.429778742031459	3.2910155046445766	94
2026-05-19 14:13:19.872748	S156	6.437213941308485	3.2987366206136812	95
2026-05-19 14:13:19.872748	S156	6.438558593387569	3.3023185816296348	96
2026-05-19 14:13:19.872748	S156	6.437222103280149	3.3109126239101556	97
2026-05-19 14:13:19.872748	S156	6.432511621624812	3.3179809834818457	98
2026-05-19 14:13:19.872748	S156	6.432128995522717	3.320118011193358	99
2026-05-19 14:13:19.872748	S156	6.432339439915793	3.3208688587651523	100
2026-05-19 14:13:19.872748	S156	6.453170128614076	3.31201199729648	101
2026-05-19 14:13:19.872748	S156	6.458278688163816	3.3082872698153096	102
2026-05-19 14:13:19.872748	S156	6.458632868521036	3.3080592627921703	103
2026-05-19 14:13:19.872748	S156	6.459066517019849	3.307736739005634	104
2026-05-19 14:13:19.872748	S156	6.455844826695653	3.310514228007321	105
2026-05-19 14:13:19.872748	S156	6.4520826197576895	3.3129464758149254	106
2026-05-19 14:13:19.872748	S156	6.438082548912789	3.318986782686636	107
2026-05-19 14:13:19.872748	S156	6.432556567929581	3.321446957826396	108
2026-05-19 14:13:19.872748	S156	6.4319199303144075	3.3224464039760733	109
2026-05-19 14:13:19.872748	S156	6.437094279049319	3.333762790405217	110
2026-05-19 14:13:19.872748	S156	6.437625873976998	3.337507565612583	111
2026-05-19 14:13:19.872748	S156	6.435570370507776	3.347029993996955	112
2026-05-19 14:13:19.872748	S156	6.4358184489544925	3.3483852459771413	113
2026-05-19 14:13:19.872748	S156	6.439149776348984	3.3571230547943287	114
2026-05-19 14:13:19.872748	S156	6.439064488801108	3.359173114029204	115
2026-05-19 14:13:19.872748	S156	6.431415386426039	3.366252543656742	116
2026-05-19 14:13:19.872748	S156	6.430840765119825	3.3686181534615685	117
2026-05-19 14:13:19.872748	S156	6.436239685490705	3.380302482346764	118
2026-05-19 14:13:19.872748	S156	6.4363966324711726	3.3819213927863245	119
2026-05-19 14:13:19.872748	S156	6.433414631551273	3.3943593632403406	120
2026-05-19 14:13:19.872748	S156	6.43537647623188	3.396215187403641	121
2026-05-19 14:13:19.872748	S156	6.43830859877805	3.396824093156141	122
2026-05-19 14:13:19.872748	S156	6.44920843870014	3.3897124748618523	123
2026-05-19 14:13:19.872748	S156	6.44984536435728	3.386224149479901	124
2026-05-19 14:13:19.872748	S156	6.451209325051721	3.382712959524838	125
2026-05-19 14:13:19.872748	S156	6.453182226109774	3.3800764976100197	126
2026-05-19 14:13:19.872748	S156	6.456928298044204	3.3788788498852966	127
2026-05-19 14:13:19.872748	S156	6.462215965315565	3.379289545073675	128
2026-05-19 14:13:19.872748	S156	6.46263309017619	3.3814261022652516	129
2026-05-19 14:13:19.872748	S156	6.462734352145162	3.3824782876710344	130
2026-05-19 14:13:19.872748	S157	6.430833386892971	2.7098418861795324	1
2026-05-19 14:13:19.872748	S157	6.434169640892758	2.708308335947592	2
2026-05-19 14:13:19.872748	S157	6.435813525126322	2.7075534610814245	3
2026-05-19 14:13:19.872748	S157	6.43663164206431	2.707179873059058	4
2026-05-19 14:13:19.872748	S157	6.437545387467075	2.7067562426804272	5
2026-05-19 14:13:19.872748	S157	6.43814666597224	2.7067165814621497	6
2026-05-19 14:13:19.872748	S157	6.439075938660016	2.706665155656715	7
2026-05-19 14:13:19.872748	S157	6.439845461265318	2.706617300914612	8
2026-05-19 14:13:19.872748	S157	6.4406647099465495	2.7064963073439543	9
2026-05-19 14:13:19.872748	S157	6.441124447943352	2.7064341299436308	10
2026-05-19 14:13:19.872748	S157	6.441692786636411	2.7066907236299222	11
2026-05-19 14:13:19.872748	S157	6.442597749960829	2.7068774870217354	12
2026-05-19 14:13:19.872748	S157	6.443455862282427	2.7070551338990896	13
2026-05-19 14:13:19.872748	S157	6.444566327249543	2.7067598818667236	14
2026-05-19 14:13:19.872748	S157	6.444789555554146	2.7067394657202843	15
2026-05-19 14:13:19.872748	S157	6.445012783858749	2.706719049573845	16
2026-05-19 14:13:19.872748	S157	6.446102841426895	2.7066094495924458	17
2026-05-19 14:13:19.872748	S157	6.447192898995041	2.7064335939027417	18
2026-05-19 14:13:19.872748	S157	6.447770986702859	2.706446288924665	19
2026-05-19 14:13:19.872748	S157	6.450567013258221	2.7078758443312827	20
2026-05-19 14:13:19.872748	S157	6.455887988916274	2.7172136769831354	21
2026-05-19 14:13:19.872748	S157	6.456792385165016	2.7283240997177245	22
2026-05-19 14:13:19.872748	S157	6.451906224680187	2.736116938546715	23
2026-05-19 14:13:19.872748	S157	6.446672115783485	2.7425609074106205	24
2026-05-19 14:13:19.872748	S157	6.44392490256778	2.750352689812047	25
2026-05-19 14:13:19.872748	S157	6.450154945731654	2.784828728808918	26
2026-05-19 14:13:19.872748	S157	6.4556335172823935	2.792091053442377	27
2026-05-19 14:13:19.872748	S157	6.456729520342023	2.7996423332329528	28
2026-05-19 14:13:19.872748	S157	6.454506074587492	2.8083644389802203	29
2026-05-19 14:13:19.872748	S157	6.450758182521099	2.819063300009816	30
2026-05-19 14:13:19.872748	S157	6.43926984414226	2.8328956711597755	31
2026-05-19 14:13:19.872748	S157	6.42382130511119	2.857170338189121	32
2026-05-19 14:13:19.872748	S157	6.414452712677658	2.8762466430654285	33
2026-05-19 14:13:19.872748	S157	6.412644449526134	2.8783986250776366	34
2026-05-19 14:13:19.872748	S157	6.407850822817434	2.8867774464616787	35
2026-05-19 14:13:19.872748	S157	6.40765145197166	2.8999259699936317	36
2026-05-19 14:13:19.872748	S157	6.408141714800692	2.9218421276974027	37
2026-05-19 14:13:19.872748	S157	6.407640062324447	2.9332603300138302	38
2026-05-19 14:13:19.872748	S157	6.40805378572918	2.9431259032582915	39
2026-05-19 14:13:19.872748	S157	6.408810780722831	2.9567581000874554	40
2026-05-19 14:13:19.872748	S157	6.4093011439179435	2.9656849528465443	41
2026-05-19 14:13:19.872748	S157	6.407464540634265	2.978768762830043	42
2026-05-19 14:13:19.872748	S157	6.406169209275703	2.9856109123815884	43
2026-05-19 14:13:19.872748	S157	6.411859862480128	3.007097929859853	44
2026-05-19 14:13:19.872748	S157	6.411199276772024	3.0146606641147287	45
2026-05-19 14:13:19.872748	S157	6.410698029690266	3.0200073338357925	46
2026-05-19 14:13:19.872748	S157	6.410019598699563	3.0271601579156595	47
2026-05-19 14:13:19.872748	S157	6.409209399245455	3.032117766213787	48
2026-05-19 14:13:19.872748	S157	6.410060266291538	3.036565197598179	49
2026-05-19 14:13:19.872748	S157	6.414777168934506	3.049976920341294	50
2026-05-19 14:13:19.872748	S157	6.415558197114393	3.0560123175735328	51
2026-05-19 14:13:19.872748	S157	6.415585956420259	3.0619783605317537	52
2026-05-19 14:13:19.872748	S157	6.411317981626269	3.0652026359646527	53
2026-05-19 14:13:19.872748	S157	6.409874723742448	3.0666445294209836	54
2026-05-19 14:13:19.872748	S157	6.4100751171334664	3.0759171923993733	55
2026-05-19 14:13:19.872748	S157	6.410432997532496	3.0822202529548974	56
2026-05-19 14:13:19.872748	S157	6.407140583535977	3.0944448873989927	57
2026-05-19 14:13:19.872748	S157	6.407566221717488	3.099990727216948	58
2026-05-19 14:13:19.872748	S157	6.409574446817942	3.107705626956573	59
2026-05-19 14:13:19.872748	S157	6.413910123973068	3.1152938117107567	60
2026-05-19 14:13:19.872748	S157	6.411478157945652	3.127905263156947	61
2026-05-19 14:13:19.872748	S157	6.410141203340558	3.137472212243381	62
2026-05-19 14:13:19.872748	S157	6.4116734709468375	3.1469711563810847	63
2026-05-19 14:13:19.872748	S157	6.412235398987619	3.1522536607055827	64
2026-05-19 14:13:19.872748	S157	6.412049971867958	3.1547407806594663	65
2026-05-19 14:13:19.872748	S157	6.410639185898901	3.1570389450560867	66
2026-05-19 14:13:19.872748	S157	6.408989428219712	3.159003530417891	67
2026-05-19 14:13:19.872748	S157	6.405216638225326	3.1632840149539447	68
2026-05-19 14:13:19.872748	S157	6.404744604869052	3.1694125629994687	69
2026-05-19 14:13:19.872748	S157	6.404977501808553	3.1703049703056365	70
2026-05-19 14:13:19.872748	S157	6.413680815649528	3.1776226672490395	71
2026-05-19 14:13:19.872748	S157	6.415326030594201	3.1804134985221424	72
2026-05-19 14:13:19.872748	S157	6.4155456165808005	3.181201092932497	73
2026-05-19 14:13:19.872748	S157	6.413016248878677	3.1866472290188597	74
2026-05-19 14:13:19.872748	S157	6.407087357917106	3.192842882601923	75
2026-05-19 14:13:19.872748	S157	6.407091714727457	3.198162747571075	76
2026-05-19 14:13:19.872748	S157	6.412695756114516	3.202195909290964	77
2026-05-19 14:13:19.872748	S157	6.416623393888216	3.201008038899346	78
2026-05-19 14:13:19.872748	S157	6.417719394716244	3.1995200261578134	79
2026-05-19 14:13:19.872748	S157	6.422570699803558	3.1989847094658046	80
2026-05-19 14:13:19.872748	S157	6.428639726333259	3.1999512177159204	81
2026-05-19 14:13:19.872748	S157	6.432178008974603	3.1992871176654205	82
2026-05-19 14:13:19.872748	S157	6.434405254804403	3.201055524588611	83
2026-05-19 14:13:19.872748	S157	6.433238791596821	3.2054405097899803	84
2026-05-19 14:13:19.872748	S157	6.434305621910028	3.212093276125273	85
2026-05-19 14:13:19.872748	S157	6.435195708450358	3.218422513562871	86
2026-05-19 14:13:19.872748	S157	6.435542425265837	3.222964758257177	87
2026-05-19 14:13:19.872748	S157	6.434941202765501	3.2292242813069834	88
2026-05-19 14:13:19.872748	S157	6.437027196618345	3.236689038594278	89
2026-05-19 14:13:19.872748	S157	6.434990856097727	3.2399024724104777	90
2026-05-19 14:13:19.872748	S157	6.433469324630323	3.2412774060689173	91
2026-05-19 14:13:19.872748	S157	6.428654708870518	3.2434988742381847	92
2026-05-19 14:13:19.872748	S157	6.425313366473077	3.24537221459849	93
2026-05-19 14:13:19.872748	S157	6.428072493418135	3.2679335975688844	94
2026-05-19 14:13:19.872748	S157	6.429778742031459	3.2910155046445766	95
2026-05-19 14:13:19.872748	S157	6.437075516495071	3.2974770892164145	96
2026-05-19 14:13:19.872748	S157	6.438558593387569	3.3023185816296348	97
2026-05-19 14:13:19.872748	S157	6.437222103280149	3.3109126239101556	98
2026-05-19 14:13:19.872748	S157	6.431888914307862	3.31686107239031	99
2026-05-19 14:13:19.872748	S157	6.431396265624954	3.3187829339370296	100
2026-05-19 14:13:19.872748	S157	6.431899570966834	3.32062079189339	101
2026-05-19 14:13:19.872748	S157	6.450098286267561	3.3135205410310675	102
2026-05-19 14:13:19.872748	S157	6.454213454038637	3.3113308546409	103
2026-05-19 14:13:19.872748	S157	6.458278688163816	3.3082872698153096	104
2026-05-19 14:13:19.872748	S157	6.459066683593349	3.307736739005634	105
2026-05-19 14:13:19.872748	S157	6.455619069332343	3.3110925059611134	106
2026-05-19 14:13:19.872748	S157	6.451240027706703	3.3136665760423227	107
2026-05-19 14:13:19.872748	S157	6.438082548912789	3.318986782686636	108
2026-05-19 14:13:19.872748	S157	6.431932563621672	3.3212962480822625	109
2026-05-19 14:13:19.872748	S157	6.437094279049319	3.333762790405217	110
2026-05-19 14:13:19.872748	S157	6.437301395107738	3.3371559095434407	111
2026-05-19 14:13:19.872748	S157	6.437084841495874	3.339756950744274	112
2026-05-19 14:13:19.872748	S157	6.4354206104515725	3.34507076732973	113
2026-05-19 14:13:19.872748	S157	6.439149776348984	3.3571230547943287	114
2026-05-19 14:13:19.872748	S157	6.439063822478602	3.359173114029261	115
2026-05-19 14:13:19.872748	S157	6.431415386426039	3.366252543656742	116
2026-05-19 14:13:19.872748	S157	6.43041644089584	3.3681157876490886	117
2026-05-19 14:13:19.872748	S157	6.435790405800674	3.3807797298679247	118
2026-05-19 14:13:19.872748	S157	6.432865508786705	3.39461054614614	119
2026-05-19 14:13:19.872748	S157	6.43547631629302	3.3969184995401918	120
2026-05-19 14:13:19.872748	S157	6.43842655277696	3.397203152633324	121
2026-05-19 14:13:19.872748	S157	6.449208105545907	3.389712307222169	122
2026-05-19 14:13:19.872748	S157	6.449990730738904	3.386274275631351	123
2026-05-19 14:13:19.872748	S157	6.451301725482011	3.382788778497286	124
2026-05-19 14:13:19.872748	S157	6.453278504079506	3.380202991245568	125
2026-05-19 14:13:19.872748	S157	6.456951916515479	3.379047402885618	126
2026-05-19 14:13:19.872748	S157	6.462160406228421	3.3793335304544883	127
2026-05-19 14:13:19.872748	S157	6.4627345187174825	3.382478287671148	128
2026-05-19 14:13:19.872748	S158	6.4455972331257385	2.8609131768460827	1
2026-05-19 14:13:19.872748	S158	6.445847108846607	2.8591187527476905	2
2026-05-19 14:13:19.872748	S158	6.446177445319179	2.858786314629498	3
2026-05-19 14:13:19.872748	S158	6.4469889231294815	2.858222615211389	4
2026-05-19 14:13:19.872748	S158	6.470817234815939	2.8624120685024934	5
2026-05-19 14:13:19.872748	S158	6.471323990118748	2.8624138175231053	6
2026-05-19 14:13:19.872748	S158	6.471750700003241	2.862173996845769	7
2026-05-19 14:13:19.872748	S158	6.472321493181269	2.862023411768888	8
2026-05-19 14:13:19.872748	S159	6.436702621424786	3.4419826471853696	1
2026-05-19 14:13:19.872748	S159	6.437075409291129	3.4436653592110664	2
2026-05-19 14:13:19.872748	S159	6.437865282686557	3.4493026815702157	3
2026-05-19 14:13:19.872748	S159	6.440174158873675	3.4523485502550386	4
2026-05-19 14:13:19.872748	S159	6.442323956674628	3.4521199294183154	5
2026-05-19 14:13:19.872748	S159	6.444257166024714	3.452181800257102	6
2026-05-19 14:13:19.872748	S159	6.4483568313643245	3.451817342017992	7
2026-05-19 14:13:19.872748	S159	6.449680643386397	3.452241896666945	8
2026-05-19 14:13:19.872748	S159	6.450597684973677	3.453587510494592	9
2026-05-19 14:13:19.872748	S159	6.450914303521753	3.4545589111715893	10
2026-05-19 14:13:19.872748	S159	6.450925846197765	3.455837331575604	11
2026-05-19 14:13:19.872748	S159	6.449255203996141	3.46042761957912	12
2026-05-19 14:13:19.872748	S159	6.448911005550336	3.4636215222676165	13
2026-05-19 14:13:19.872748	S159	6.450116159645064	3.467704927932634	14
2026-05-19 14:13:19.872748	S159	6.451545224429635	3.46785624977924	15
2026-05-19 14:13:19.872748	S159	6.45667791076179	3.466350663170064	16
2026-05-19 14:13:19.872748	S159	6.4593973784100704	3.465956763112453	17
2026-05-19 14:13:19.872748	S159	6.462935263207286	3.4662379243260233	18
2026-05-19 14:13:19.872748	S159	6.528017990860386	3.463081024247036	19
2026-05-19 14:13:19.872748	S159	6.5523891	3.4728735	20
2026-05-19 14:13:19.872748	S160	6.436702621424786	3.4419826471853696	1
2026-05-19 14:13:19.872748	S160	6.4371090837078215	3.4436569059225226	2
2026-05-19 14:13:19.872748	S160	6.43796280925258	3.4492536099520086	3
2026-05-19 14:13:19.872748	S160	6.440228564667934	3.4522703341062027	4
2026-05-19 14:13:19.872748	S160	6.442323956674628	3.4521199294183154	5
2026-05-19 14:13:19.872748	S160	6.445765613932169	3.4520112337417794	6
2026-05-19 14:13:19.872748	S160	6.449272062603984	3.4519879085322343	7
2026-05-19 14:13:19.872748	S160	6.450597684973677	3.453587510494592	8
2026-05-19 14:13:19.872748	S160	6.450925846197765	3.455837331575604	9
2026-05-19 14:13:19.872748	S160	6.449068768139621	3.4604787895335947	10
2026-05-19 14:13:19.872748	S160	6.448741518276073	3.464064995205022	11
2026-05-19 14:13:19.872748	S160	6.449590361466378	3.4681226759019568	12
2026-05-19 14:13:19.872748	S160	6.450742692209557	3.468524646528843	13
2026-05-19 14:13:19.872748	S160	6.454408702017936	3.467910255587074	14
2026-05-19 14:13:19.872748	S160	6.458849855190632	3.4666916968281014	15
2026-05-19 14:13:19.872748	S160	6.465801262981345	3.466993846882545	16
2026-05-19 14:13:19.872748	S160	6.495409709522848	3.467689021344061	17
2026-05-19 14:13:19.872748	S160	6.5393273	3.5010197	18
2026-05-19 14:13:19.872748	S161	6.436702621424786	3.4419826471853696	1
2026-05-19 14:13:19.872748	S161	6.4372288397857576	3.443666992206885	2
2026-05-19 14:13:19.872748	S161	6.4376495934942195	3.445986728202562	3
2026-05-19 14:13:19.872748	S161	6.438303588965708	3.449117725432145	4
2026-05-19 14:13:19.872748	S161	6.440393665550367	3.4519715829444886	5
2026-05-19 14:13:19.872748	S161	6.445765613932169	3.4516980694723083	6
2026-05-19 14:13:19.872748	S161	6.449272062603984	3.4519879085322343	7
2026-05-19 14:13:19.872748	S161	6.4508381434881175	3.4539006747649443	8
2026-05-19 14:13:19.872748	S161	6.450812689283228	3.4563640169388448	9
2026-05-19 14:13:19.872748	S161	6.44936580598782	3.4599805736491462	10
2026-05-19 14:13:19.872748	S161	6.448967832990185	3.4648763753588563	11
2026-05-19 14:13:19.872748	S161	6.4497600972135425	3.468179614859655	12
2026-05-19 14:13:19.872748	S161	6.450940716805418	3.4683538296537875	13
2026-05-19 14:13:19.872748	S161	6.454550147134576	3.4676824997552016	14
2026-05-19 14:13:19.872748	S161	6.459921802258204	3.467615067431248	15
2026-05-19 14:13:19.872748	S161	6.4650988191676655	3.468415474020915	16
2026-05-19 14:13:19.872748	S161	6.492278408933654	3.4722858794872256	17
2026-05-19 14:13:19.872748	S161	6.521080293664063	3.5344788628666293	18
2026-05-19 14:13:19.872748	S161	6.537885027284704	3.566467854961183	19
2026-05-19 14:13:19.872748	S161	6.5632172	3.5890471	20
2026-05-19 14:13:19.872748	S162	6.424158898708965	3.3521236826844127	1
2026-05-19 14:13:19.872748	S162	6.426552125086341	3.3550139922474087	2
2026-05-19 14:13:19.872748	S162	6.428519730888787	3.358149104682693	3
2026-05-19 14:13:19.872748	S162	6.427659863511215	3.359255052254533	4
2026-05-19 14:13:19.872748	S162	6.432523903419837	3.3644467344529296	5
2026-05-19 14:13:19.872748	S162	6.439064008253442	3.3591730805353257	6
2026-05-19 14:13:19.872748	S163	6.424158024591193	3.352172281143254	1
2026-05-19 14:13:19.872748	S163	6.426330269704778	3.3477647193057862	2
2026-05-19 14:13:19.872748	S164	6.426358133440893	3.347764109790347	1
2026-05-19 14:13:19.872748	S164	6.423671898279153	3.3488889807153273	2
2026-05-19 14:13:19.872748	S164	6.422210900422988	3.3493211647678094	3
2026-05-19 14:13:19.872748	S164	6.427430993645757	3.3556066785051613	4
2026-05-19 14:13:19.872748	S164	6.432960952557403	3.3634513209103636	5
2026-05-19 14:13:19.872748	S164	6.439063191871019	3.359173518605778	6
2026-05-19 14:13:19.872748	S165	6.422183975855731	3.3493182595578617	1
2026-05-19 14:13:19.872748	S165	6.426301153186884	3.3477947223932745	2
2026-05-19 14:13:19.872748	S166	6.418094084	3.362453877	1
2026-05-19 14:13:19.872748	S166	6.417867445809533	3.358957304304056	2
2026-05-19 14:13:19.872748	S166	6.41838310861624	3.354177506749585	3
2026-05-19 14:13:19.872748	S166	6.418006278103647	3.352571018774845	4
2026-05-19 14:13:19.872748	S166	6.41781885536157	3.350520788694608	5
2026-05-19 14:13:19.872748	S166	6.4191566028263	3.34949687511948	6
2026-05-19 14:13:19.872748	S166	6.420584592137179	3.348782880464041	7
2026-05-19 14:13:19.872748	S166	6.421536585011099	3.348683714539674	8
2026-05-19 14:13:19.872748	S166	6.42221793457128	3.349367926556892	9
2026-05-19 14:13:19.872748	S166	6.42422027407363	3.35212872799195	10
2026-05-19 14:13:19.872748	S166	6.42642412400888	3.35554483070657	11
2026-05-19 14:13:19.872748	S166	6.426971742322559	3.35578270020135	12
2026-05-19 14:13:19.872748	S166	6.427928138699581	3.3577350772919665	13
2026-05-19 14:13:19.872748	S166	6.427660217332676	3.359255169204363	14
2026-05-19 14:13:19.872748	S166	6.432754563492885	3.3642176259488137	15
2026-05-19 14:13:19.872748	S166	6.4390793	3.3592365	16
2026-05-19 14:13:19.872748	S168	6.424469742978864	3.152975976991251	1
2026-05-19 14:13:19.872748	S168	6.424451966525188	3.1530220247297267	2
2026-05-19 14:13:19.872748	S168	6.4247921148404465	3.154339648614596	3
2026-05-19 14:13:19.872748	S168	6.425072531453566	3.155778200402815	4
2026-05-19 14:13:19.872748	S168	6.427378816790322	3.1597425032358455	5
2026-05-19 14:13:19.872748	S168	6.429554487314493	3.1616964260238416	6
2026-05-19 14:13:19.872748	S168	6.434323925991501	3.163376410336806	7
2026-05-19 14:13:19.872748	S168	6.437949834786924	3.164501692376765	8
2026-05-19 14:13:19.872748	S168	6.439847249297308	3.1662403891790896	9
2026-05-19 14:13:19.872748	S168	6.441301715347479	3.1687691798082023	10
2026-05-19 14:13:19.872748	S168	6.441385456571112	3.172741640428719	11
2026-05-19 14:13:19.872748	S168	6.440575492880162	3.174754262074168	12
2026-05-19 14:13:19.872748	S168	6.4386529605975085	3.178421185353133	13
2026-05-19 14:13:19.872748	S168	6.438700022813563	3.180380672273963	14
2026-05-19 14:13:19.872748	S168	6.438713613176365	3.182297819453152	15
2026-05-19 14:13:19.872748	S168	6.438646567386544	3.182901231561536	16
2026-05-19 14:13:19.872748	S168	6.438110201067981	3.183772826829201	17
2026-05-19 14:13:19.872748	S168	6.438110201067981	3.184242147357944	18
2026-05-19 14:13:19.872748	S168	6.440657941081157	3.187929665798067	19
2026-05-19 14:13:19.872748	S168	6.440859078450618	3.187058070530402	20
2026-05-19 14:13:19.872748	S168	6.441395444769181	3.186253521052557	21
2026-05-19 14:13:19.872748	S168	6.442334085826667	3.184912605256148	22
2026-05-19 14:13:19.872748	S168	6.443473864253614	3.18357168945974	23
2026-05-19 14:13:19.872748	S168	6.44434545952128	3.183102368930997	24
2026-05-19 14:13:19.872748	S168	6.445150008999125	3.183236460510638	25
2026-05-19 14:13:19.872748	S168	6.446088650056611	3.184108055778303	26
2026-05-19 14:13:19.872748	S168	6.446692062164995	3.185583063154353	27
2026-05-19 14:13:19.872748	S168	6.446960245324276	3.187192162110043	28
2026-05-19 14:13:19.872748	S168	6.446625016375174	3.188868306855553	29
2026-05-19 14:13:19.872748	S168	6.446490924795533	3.19007513107232	30
2026-05-19 14:13:19.872748	S168	6.448971619018889	3.190477405811243	31
2026-05-19 14:13:19.872748	S168	6.44923980217817	3.192421733716035	32
2026-05-19 14:13:19.872748	S168	6.449303515470205	3.1941622858448095	33
2026-05-19 14:13:19.872748	S168	6.449306847967991	3.195237656888493	34
2026-05-19 14:13:19.872748	S168	6.448301161120685	3.195908114786697	35
2026-05-19 14:13:19.872748	S168	6.448032977961403	3.19644448110526	36
2026-05-19 14:13:19.872748	S168	6.448636390069787	3.197181984793285	37
2026-05-19 14:13:19.872748	S168	6.449038664808709	3.197919488481309	38
2026-05-19 14:13:19.872748	S168	6.448167069541044	3.198724037959154	39
2026-05-19 14:13:19.872748	S168	6.448703435859607	3.199260404277718	40
2026-05-19 14:13:19.872748	S168	6.4510159675199095	3.2016986772691065	41
2026-05-19 14:13:19.872748	S168	6.453176016321364	3.204245472039803	42
2026-05-19 14:13:19.872748	S170	6.43922746	3.424595555	1
2026-05-19 14:13:19.872748	S170	6.439759245888567	3.4241402329127197	2
2026-05-19 14:13:19.872748	S170	6.438719123448962	3.4226416406281714	3
2026-05-19 14:13:19.872748	S170	6.437326802869208	3.419035321512098	4
2026-05-19 14:13:19.872748	S170	6.43728133806227	3.416133490164583	5
2026-05-19 14:13:19.872748	S170	6.438048313113427	3.4128761827153937	6
2026-05-19 14:13:19.872748	S170	6.440536053387802	3.410414445080022	7
2026-05-19 14:13:19.872748	S170	6.44128749811496	3.4078888788606037	8
2026-05-19 14:13:19.872748	S170	6.441474200271841	3.405760910388693	9
2026-05-19 14:13:19.872748	S170	6.441212273188455	3.4049151032673706	10
2026-05-19 14:13:19.872748	S170	6.439955614909522	3.403704144359324	11
2026-05-19 14:13:19.872748	S170	6.438816535772091	3.403458480088773	12
2026-05-19 14:13:19.872748	S170	6.4273334505166275	3.4015299173765072	13
2026-05-19 14:13:19.872748	S170	6.3997113254552715	3.399226110329664	14
2026-05-19 14:13:19.872748	S170	6.398104828087796	3.3990718316701134	15
2026-05-19 14:13:19.872748	S170	6.397303586321563	3.3976038529129795	16
2026-05-19 14:13:19.872748	S170	6.398650612346827	3.3960782280121293	17
2026-05-19 14:13:19.872748	S170	6.4010654	3.3965995	18
2026-05-19 14:13:19.872748	S171	6.601832	3.4862304	1
2026-05-19 14:13:19.872748	S171	6.546801048532899	3.4536609309143103	2
2026-05-19 14:13:19.872748	S171	6.46117059807689	3.4643444895650646	3
2026-05-19 14:13:19.872748	S171	6.448933884778654	3.4667549447163992	4
2026-05-19 14:13:19.872748	S171	6.448269830901538	3.464137180540831	5
2026-05-19 14:13:19.872748	S171	6.448216025442321	3.4617817418618415	6
2026-05-19 14:13:19.872748	S171	6.450072310496438	3.4560285152039114	7
2026-05-19 14:13:19.872748	S171	6.449485123024033	3.453347895321599	8
2026-05-19 14:13:19.872748	S171	6.443063568237605	3.4535807050599203	9
2026-05-19 14:13:19.872748	S171	6.441137260570841	3.453417440672041	10
2026-05-19 14:13:19.872748	S171	6.439983047015957	3.452676494863482	11
2026-05-19 14:13:19.872748	S171	6.43754593338997	3.4494329446069116	12
2026-05-19 14:13:19.872748	S171	6.436918319180791	3.4437167600645466	13
2026-05-19 14:13:19.872748	S171	6.436702694961895	3.4419822683274788	14
2026-05-19 14:13:19.872748	S171	6.438618821371541	3.440145650103247	15
2026-05-19 14:13:19.872748	S171	6.441472331827942	3.4358748161680595	16
2026-05-19 14:13:19.872748	S171	6.44154567764771	3.435663125040918	17
2026-05-19 14:13:19.872748	S171	6.441657372221357	3.4296620679659497	18
2026-05-19 14:13:19.872748	S171	6.442095174	3.427179994	19
2026-05-19 14:13:19.872748	S172	6.536139	3.553069	1
2026-05-19 14:13:19.872748	S172	6.4940117930292445	3.470635686121085	2
2026-05-19 14:13:19.872748	S172	6.462439588998464	3.4670143680869216	3
2026-05-19 14:13:19.872748	S172	6.448935778983639	3.4667549792819727	4
2026-05-19 14:13:19.872748	S172	6.44819240074419	3.464132750036356	5
2026-05-19 14:13:19.872748	S172	6.44813475857184	3.4617355754291452	6
2026-05-19 14:13:19.872748	S172	6.44997107976539	3.4560515286549673	7
2026-05-19 14:13:19.872748	S172	6.4494285310141635	3.4534055068806992	8
2026-05-19 14:13:19.872748	S172	6.442977443346365	3.453651565085835	9
2026-05-19 14:13:19.872748	S172	6.4410298536526795	3.453457064738103	10
2026-05-19 14:13:19.872748	S172	6.44058383969417	3.4533224106516514	11
2026-05-19 14:13:19.872748	S172	6.439919633225514	3.4527443718940845	12
2026-05-19 14:13:19.872748	S172	6.4374865430526	3.449457862235903	13
2026-05-19 14:13:19.872748	S172	6.436883529920593	3.443717301000845	14
2026-05-19 14:13:19.872748	S172	6.436702845603293	3.4419823237827245	15
2026-05-19 14:13:19.872748	S172	6.438523240434364	3.4400464892414675	16
2026-05-19 14:13:19.872748	S172	6.441307761165696	3.4358257070941676	17
2026-05-19 14:13:19.872748	S172	6.441361655582341	3.4356474122120346	18
2026-05-19 14:13:19.872748	S172	6.441545575929794	3.4296359596264665	19
2026-05-19 14:13:19.872748	S172	6.442095174	3.427179994	20
2026-05-19 14:13:19.872748	S173	6.601832	3.4862304	1
2026-05-19 14:13:19.872748	S173	6.591588911342527	3.476071390806169	2
2026-05-19 14:13:19.872748	S173	6.587939990538821	3.472009614575626	3
2026-05-19 14:13:19.872748	S173	6.535912121983031	3.4321890529887185	4
2026-05-19 14:13:19.872748	S173	6.492415447606703	3.400905291241486	5
2026-05-19 14:13:19.872748	S173	6.470452067537273	3.3858497276988544	6
2026-05-19 14:13:19.872748	S173	6.4658432427404335	3.3811658412014935	7
2026-05-19 14:13:19.872748	S173	6.460423828807869	3.3753125028239026	8
2026-05-19 14:13:19.872748	S173	6.451761547864606	3.3733754684188284	9
2026-05-19 14:13:19.872748	S173	6.447537509135387	3.3749802836868525	10
2026-05-19 14:13:19.872748	S173	6.447555329428127	3.376052535935173	11
2026-05-19 14:13:19.872748	S173	6.438159873720281	3.39645782860282	12
2026-05-19 14:13:19.872748	S173	6.437475697441286	3.3963400001297828	13
2026-05-19 14:13:19.872748	S173	6.433247586067935	3.393868106762085	14
2026-05-19 14:13:19.872748	S173	6.436801277022511	3.3816394372364584	15
2026-05-19 14:13:19.872748	S173	6.436932766546306	3.380889602967528	16
2026-05-19 14:13:19.872748	S173	6.436874326762407	3.380330902924811	17
2026-05-19 14:13:19.872748	S173	6.43226229786319	3.370142999927623	18
2026-05-19 14:13:19.872748	S173	6.432013351682997	3.3692547814365525	19
2026-05-19 14:13:19.872748	S173	6.431900194287962	3.367979390782665	20
2026-05-19 14:13:19.872748	S173	6.432986504241228	3.365360284976049	21
2026-05-19 14:13:19.872748	S173	6.435090410683706	3.362998672444931	22
2026-05-19 14:13:19.872748	S173	6.4390793	3.3592365	23
2026-05-19 14:13:19.872748	S174	6.462767750725462	3.3825329213594273	1
2026-05-19 14:13:19.872748	S174	6.461718393242336	3.379709709565617	2
2026-05-19 14:13:19.872748	S174	6.4569667339603285	3.3795961817199327	3
2026-05-19 14:13:19.872748	S174	6.453615441751367	3.3807319031366205	4
2026-05-19 14:13:19.872748	S174	6.449206760040838	3.389712919245568	5
2026-05-19 14:13:19.872748	S175	6.5482938	3.4068744	1
2026-05-19 14:13:19.872748	S175	6.547351296052128	3.4084175044855556	2
2026-05-19 14:13:19.872748	S175	6.530597379832628	3.409019234146399	3
2026-05-19 14:13:19.872748	S175	6.528355070748717	3.399905528234399	4
2026-05-19 14:13:19.872748	S175	6.5124118027403455	3.4076548708629417	5
2026-05-19 14:13:19.872748	S175	6.486190882759416	3.398269318763738	6
2026-05-19 14:13:19.872748	S175	6.469224024421017	3.386543924942302	7
2026-05-19 14:13:19.872748	S175	6.462767986870944	3.382533438705593	8
2026-05-19 14:13:19.872748	S175	6.462820002085024	3.3814385562310605	9
2026-05-19 14:13:19.872748	S175	6.462520670564089	3.3790652965622314	10
2026-05-19 14:13:19.872748	S175	6.457065904335678	3.378061493687511	11
2026-05-19 14:13:19.872748	S175	6.447536280448162	3.3749827372821244	12
2026-05-19 14:13:19.872748	S175	6.448601448045821	3.3785052541190908	13
2026-05-19 14:13:19.872748	S175	6.4492281047334075	3.3854991750372108	14
2026-05-19 14:13:19.872748	S175	6.449207769577413	3.389712736645123	15
2026-05-19 14:13:19.872748	S175	6.438776476445426	3.402228278932	16
2026-05-19 14:13:19.872748	S175	6.43893169787971	3.402898151243221	17
2026-05-19 14:13:19.872748	S175	6.440034147455037	3.4036358886018263	18
2026-05-19 14:13:19.872748	S175	6.44126449169255	3.404883645003423	19
2026-05-19 14:13:19.872748	S175	6.441527401176572	3.405751405550518	20
2026-05-19 14:13:19.872748	S175	6.441350946017437	3.407902387996657	21
2026-05-19 14:13:19.872748	S175	6.44061323479313	3.4104234567243417	22
2026-05-19 14:13:19.872748	S175	6.438126790586162	3.412945827826933	23
2026-05-19 14:13:19.872748	S175	6.4374645344195125	3.417770922911754	24
2026-05-19 14:13:19.872748	S175	6.438903652965244	3.422658215370582	25
2026-05-19 14:13:19.872748	S175	6.442095174	3.427179994	26
2026-05-19 14:13:19.872748	S176	6.4492081354225945	3.389713112398539	1
2026-05-19 14:13:19.872748	S176	6.438498577817327	3.397423474802679	2
2026-05-19 14:13:19.872748	S176	6.433296267775617	3.3962892062729964	3
2026-05-19 14:13:19.872748	S176	6.433146945582109	3.391981511678779	4
2026-05-19 14:13:19.872748	S176	6.43616697250242	3.3812416825550997	5
2026-05-19 14:13:19.872748	S176	6.434538305719656	3.370296642664556	6
2026-05-19 14:13:19.872748	S176	6.43479612309973	3.369909472988809	7
2026-05-19 14:13:19.872748	S176	6.433809473542169	3.3702692529812737	8
2026-05-19 14:13:19.872748	S176	6.4331868056602275	3.3701230430639555	9
2026-05-19 14:13:19.872748	S176	6.432738683287582	3.3684362298341455	10
2026-05-19 14:13:19.872748	S176	6.432884046619179	3.3643971564240474	11
2026-05-19 14:13:19.872748	S176	6.439064030138624	3.3591733817758893	12
2026-05-19 14:13:19.872748	S176	6.439262355457544	3.357112082254332	13
2026-05-19 14:13:19.872748	S176	6.439288485779798	3.3560602335198837	14
2026-05-19 14:13:19.872748	S176	6.438056990952774	3.352705318527427	15
2026-05-19 14:13:19.872748	S176	6.436646551574441	3.349749756258916	16
2026-05-19 14:13:19.872748	S176	6.435438535839381	3.3457040389264137	17
2026-05-19 14:13:19.872748	S176	6.435863591878601	3.343806330972484	18
2026-05-19 14:13:19.872748	S176	6.435329991824105	3.3433950241762034	19
2026-05-19 14:13:19.872748	S176	6.435865379827078	3.343224618696155	20
2026-05-19 14:13:19.872748	S176	6.436773896118794	3.3402558254274197	21
2026-05-19 14:13:19.872748	S176	6.437104464036324	3.3389256693545235	22
2026-05-19 14:13:19.872748	S176	6.43722527786997	3.337152026615172	23
2026-05-19 14:13:19.872748	S176	6.437005090330359	3.3345379492362213	24
2026-05-19 14:13:19.872748	S176	6.436589994779396	3.3330321824109888	25
2026-05-19 14:13:19.872748	S176	6.4318174686325875	3.3241663539735953	26
2026-05-19 14:13:19.872748	S176	6.431099232006687	3.3222487599819033	27
2026-05-19 14:13:19.872748	S176	6.430688810622087	3.3201541573145334	28
2026-05-19 14:13:19.872748	S176	6.431151480397148	3.3172669655520792	29
2026-05-19 14:13:19.872748	S176	6.434143895917174	3.312423671715976	30
2026-05-19 14:13:19.872748	S176	6.436055250286358	3.309119631167988	31
2026-05-19 14:13:19.872748	S176	6.436825028872747	3.305633730471982	32
2026-05-19 14:13:19.872748	S176	6.436680717199366	3.3002111591797245	33
2026-05-19 14:13:19.872748	S176	6.43629583398392	3.2990007528723027	34
2026-05-19 14:13:19.872748	S176	6.429464262909491	3.2921745527713426	35
2026-05-19 14:13:19.872748	S176	6.429413771011497	3.2879986400694747	36
2026-05-19 14:13:19.872748	S176	6.429096503063775	3.2854860247902025	37
2026-05-19 14:13:19.872748	S176	6.427685056188494	3.2805397761004826	38
2026-05-19 14:13:19.872748	S176	6.427357116324572	3.277054000606313	39
2026-05-19 14:13:19.872748	S176	6.427539891281199	3.271111828430719	40
2026-05-19 14:13:19.872748	S176	6.427390884500653	3.2673358322713	41
2026-05-19 14:13:19.872748	S176	6.426632303851903	3.2635189408464953	42
2026-05-19 14:13:19.872748	S176	6.425054768698175	3.2553696866160635	43
2026-05-19 14:13:19.872748	S176	6.425683980526827	3.253260101048056	44
2026-05-19 14:13:19.872748	S176	6.42773125377586	3.242040379312243	45
2026-05-19 14:13:19.872748	S176	6.436742968927732	3.2214635336343065	46
2026-05-19 14:13:19.872748	S176	6.438419386476113	3.218869582065281	47
2026-05-19 14:13:19.872748	S176	6.440593224347751	3.2167539038314885	48
2026-05-19 14:13:19.872748	S176	6.442609736679884	3.214969250083186	49
2026-05-19 14:13:19.872748	S176	6.450961069602684	3.2074427804055006	50
2026-05-19 14:13:19.872748	S176	6.452774857044332	3.205773183637973	51
2026-05-19 14:13:19.872748	S176	6.453045	3.2055781	52
2026-05-19 14:13:19.872748	S178	6.4390793	3.3592365	1
2026-05-19 14:13:19.872748	S178	6.439055181722111	3.3591390606942184	2
2026-05-19 14:13:19.872748	S178	6.4394043088887685	3.356790495616451	3
2026-05-19 14:13:19.872748	S178	6.439442944625725	3.3562726486253496	4
2026-05-19 14:13:19.872748	S178	6.438069736999111	3.352406090320386	5
2026-05-19 14:13:19.872748	S178	6.436700208806855	3.349015674309726	6
2026-05-19 14:13:19.872748	S178	6.436280219421377	3.34748125839144	7
2026-05-19 14:13:19.872748	S178	6.4360166106982035	3.346589701046696	8
2026-05-19 14:13:19.872748	S178	6.437517919849384	3.338916324364874	9
2026-05-19 14:13:19.872748	S178	6.437710050001158	3.3376170169954946	10
2026-05-19 14:13:19.872748	S178	6.437931362805159	3.335847395427095	11
2026-05-19 14:13:19.872748	S178	6.4361255512379785	3.328428304150833	12
2026-05-19 14:13:19.872748	S178	6.4323353946241895	3.321411545369159	13
2026-05-19 14:13:19.872748	S178	6.440676872929799	3.31770318655785	14
2026-05-19 14:13:19.872748	S178	6.452178670080443	3.3126998346792504	15
2026-05-19 14:13:19.872748	S178	6.458315000701006	3.308164031620805	16
2026-05-19 14:13:19.872748	S178	6.459065698603084	3.30773634763824	17
2026-05-19 14:13:19.872748	S178	6.459825735611815	3.306508347164794	18
2026-05-19 14:13:19.872748	S178	6.461086403919552	3.3047168309146855	19
2026-05-19 14:13:19.872748	S178	6.4638672039777845	3.300718448995724	20
2026-05-19 14:13:19.872748	S178	6.46761205016773	3.298498460159891	21
2026-05-19 14:13:19.872748	S178	6.474222765687571	3.294500326844343	22
2026-05-19 14:13:19.872748	S178	6.474484688	3.294149195	23
2026-05-19 14:13:19.872748	S179	6.58256785349664	3.407602775396478	1
2026-05-19 14:13:19.872748	S179	6.5822202	3.4078998	2
2026-05-19 14:13:19.872748	S179	6.5818232	3.4077758	3
2026-05-19 14:13:19.872748	S179	6.5814012	3.4076862	4
2026-05-19 14:13:19.872748	S179	6.5812489	3.4077058	5
2026-05-19 14:13:19.872748	S179	6.5811072	3.4077522	6
2026-05-19 14:13:19.872748	S179	6.5806436	3.4079573	9
2026-05-19 14:13:19.872748	S179	6.5803825	3.4081544	10
2026-05-19 14:13:19.872748	S179	6.5802865	3.4084039	11
2026-05-19 14:13:19.872748	S179	6.5801853	3.408318	12
2026-05-19 14:13:19.872748	S179	6.580056	3.4083395	13
2026-05-19 14:13:19.872748	S179	6.5799428	3.4083932	14
2026-05-19 14:13:19.872748	S179	6.579671	3.4085461	15
2026-05-19 14:13:19.872748	S179	6.5794845	3.4086802	16
2026-05-19 14:13:19.872748	S179	6.5791141	3.4088947	17
2026-05-19 14:13:19.872748	S179	6.5789223	3.4090825	18
2026-05-19 14:13:19.872748	S179	6.5789036	3.4091925	19
2026-05-19 14:13:19.872748	S179	6.5789436	3.4092274	20
2026-05-19 14:13:19.872748	S179	6.5789995	3.4092542	21
2026-05-19 14:13:19.872748	S179	6.5790555	3.409281	22
2026-05-19 14:13:19.872748	S179	6.5791248	3.4092944	23
2026-05-19 14:13:19.872748	S179	6.5791994	3.4093185	24
2026-05-19 14:13:19.872748	S179	6.57925	3.4093427	25
2026-05-19 14:13:19.872748	S179	6.5793459	3.409391	26
2026-05-19 14:13:19.872748	S179	6.5794285	3.4094634	27
2026-05-19 14:13:19.872748	S179	6.5794738	3.4094983	28
2026-05-19 14:13:19.872748	S179	6.5795657	3.4095586	29
2026-05-19 14:13:19.872748	S179	6.5796111	3.4095841	30
2026-05-19 14:13:19.872748	S179	6.5796537	3.4096109	31
2026-05-19 14:13:19.872748	S179	6.5796777	3.4096632	32
2026-05-19 14:13:19.872748	S179	6.5796936	3.4097329	33
2026-05-19 14:13:19.872748	S179	6.579719	3.4097853	34
2026-05-19 14:13:19.872748	S179	6.5797802	3.4098764	35
2026-05-19 14:13:19.872748	S179	6.5798229	3.4099462	36
2026-05-19 14:13:19.872748	S179	6.5798495	3.4100213	37
2026-05-19 14:13:19.872748	S179	6.5798895	3.4101018	38
2026-05-19 14:13:19.872748	S179	6.5798922	3.4101715	39
2026-05-19 14:13:19.872748	S179	6.5798842	3.410252	40
2026-05-19 14:13:19.872748	S179	6.5798815	3.4103271	41
2026-05-19 14:13:19.872748	S179	6.5798975	3.4104183	42
2026-05-19 14:13:19.872748	S179	6.5799002	3.4105282	43
2026-05-19 14:13:19.872748	S179	6.5799055	3.4106033	44
2026-05-19 14:13:19.872748	S179	6.5799161	3.4106677	45
2026-05-19 14:13:19.872748	S179	6.5798868	3.4107455	46
2026-05-19 14:13:19.872748	S179	6.5798309	3.4108125	47
2026-05-19 14:13:19.872748	S180	6.4493813109168485	3.1438990035366317	1
2026-05-19 14:13:19.872748	S180	6.447362818041896	3.1415487753784532	2
2026-05-19 14:13:19.872748	S181	6.430224369	3.280752801	1
2026-05-19 14:13:19.872748	S181	6.426853	3.280746	2
\.


--
-- Data for Name: stop_times_gtfs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.stop_times_gtfs (generated_at, trip_id, arrival_time, departure_time, stop_sequence, stop_id) FROM stdin;
2026-05-19 14:13:19.872748	T4_0_465	17:00:00	17:00:00	1	F2
2026-05-19 14:13:19.872748	T4_0_465	17:25:00	17:25:00	2	F14
2026-05-19 14:13:19.872748	T4_1_464	06:30:00	06:30:00	1	F14
2026-05-19 14:13:19.872748	T4_1_464	06:55:00	06:55:00	2	F2
2026-05-19 14:13:19.872748	T8_0_462	06:30:00	06:30:00	1	F3
2026-05-19 14:13:19.872748	T8_0_462	06:50:00	06:50:00	2	F7
2026-05-19 14:13:19.872748	T8_0_462	07:00:00	07:00:00	3	F2
2026-05-19 14:13:19.872748	T8_1_463	16:30:00	16:30:00	1	F2
2026-05-19 14:13:19.872748	T8_1_463	16:40:00	16:40:00	2	F7
2026-05-19 14:13:19.872748	T8_1_463	17:00:00	17:00:00	3	F3
2026-05-19 14:13:19.872748	T9_0_470	06:30:00	06:30:00	1	F3
2026-05-19 14:13:19.872748	T9_0_470	07:00:00	07:00:00	2	F1
2026-05-19 14:13:19.872748	T9_0_470	07:10:00	07:10:00	3	F6
2026-05-19 14:13:19.872748	T9_0_470	07:15:00	07:15:00	4	F5
2026-05-19 14:13:19.872748	T9_1_471	17:00:00	17:00:00	1	F5
2026-05-19 14:13:19.872748	T9_1_471	17:05:00	17:05:00	2	F6
2026-05-19 14:13:19.872748	T9_1_471	17:15:00	17:15:00	3	F1
2026-05-19 14:13:19.872748	T9_1_471	17:45:00	17:45:00	4	F3
2026-05-19 14:13:19.872748	T10_0_466	07:00:00	07:00:00	1	F3
2026-05-19 14:13:19.872748	T10_0_466	07:40:00	07:40:00	2	F10
2026-05-19 14:13:19.872748	T10_1_467	17:30:00	17:30:00	1	F10
2026-05-19 14:13:19.872748	T10_1_467	18:10:00	18:10:00	2	F3
2026-05-19 14:13:19.872748	T11_0_476	06:30:00	06:30:00	1	F3
2026-05-19 14:13:19.872748	T11_0_476	06:50:00	06:50:00	2	F12
2026-05-19 14:13:19.872748	T11_0_476	06:55:00	06:55:00	3	F7
2026-05-19 14:13:19.872748	T11_0_476	07:00:00	07:00:00	4	F2
2026-05-19 14:13:19.872748	T11_0_474	06:30:00	06:30:00	1	F3
2026-05-19 14:13:19.872748	T11_0_474	06:50:00	06:50:00	2	F12
2026-05-19 14:13:19.872748	T11_0_474	06:55:00	06:55:00	3	F7
2026-05-19 14:13:19.872748	T11_0_474	07:00:00	07:00:00	4	F2
2026-05-19 14:13:19.872748	T11_0_480	08:30:00	08:30:00	1	F3
2026-05-19 14:13:19.872748	T11_0_480	08:50:00	08:50:00	2	F12
2026-05-19 14:13:19.872748	T11_0_480	08:55:00	08:55:00	3	F7
2026-05-19 14:13:19.872748	T11_0_480	09:00:00	09:00:00	4	F2
2026-05-19 14:13:19.872748	T11_0_478	08:30:00	08:30:00	1	F3
2026-05-19 14:13:19.872748	T11_0_478	08:50:00	08:50:00	2	F12
2026-05-19 14:13:19.872748	T11_0_478	08:55:00	08:55:00	3	F7
2026-05-19 14:13:19.872748	T11_0_478	09:00:00	09:00:00	4	F2
2026-05-19 14:13:19.872748	T11_0_479	11:00:00	11:00:00	1	F3
2026-05-19 14:13:19.872748	T11_0_479	11:20:00	11:20:00	2	F12
2026-05-19 14:13:19.872748	T11_0_479	11:25:00	11:25:00	3	F7
2026-05-19 14:13:19.872748	T11_0_479	11:30:00	11:30:00	4	F2
2026-05-19 14:13:19.872748	T11_1_475	17:30:00	17:30:00	1	F2
2026-05-19 14:13:19.872748	T11_1_475	17:35:00	17:35:00	2	F7
2026-05-19 14:13:19.872748	T11_1_475	17:40:00	17:40:00	3	F12
2026-05-19 14:13:19.872748	T11_1_475	18:00:00	18:00:00	4	F3
2026-05-19 14:13:19.872748	T11_1_477	17:30:00	17:30:00	1	F2
2026-05-19 14:13:19.872748	T11_1_477	17:35:00	17:35:00	2	F7
2026-05-19 14:13:19.872748	T11_1_477	17:40:00	17:40:00	3	F12
2026-05-19 14:13:19.872748	T11_1_477	18:00:00	18:00:00	4	F3
2026-05-19 14:13:19.872748	T11_1_481	18:30:00	18:30:00	1	F2
2026-05-19 14:13:19.872748	T11_1_481	18:35:00	18:35:00	2	F7
2026-05-19 14:13:19.872748	T11_1_481	18:40:00	18:40:00	3	F12
2026-05-19 14:13:19.872748	T11_1_481	19:00:00	19:00:00	4	F3
2026-05-19 14:13:19.872748	T12_0_25	05:30:00	05:30:00	1	F27
2026-05-19 14:13:19.872748	T12_0_25	05:34:00	05:34:00	2	F99
2026-05-19 14:13:19.872748	T12_0_27	07:00:00	07:00:00	1	F27
2026-05-19 14:13:19.872748	T12_0_27	07:04:00	07:04:00	2	F99
2026-05-19 14:13:19.872748	T12_0_29	09:00:00	09:00:00	1	F27
2026-05-19 14:13:19.872748	T12_0_29	09:04:00	09:04:00	2	F99
2026-05-19 14:13:19.872748	T12_0_31	14:00:00	14:00:00	1	F27
2026-05-19 14:13:19.872748	T12_0_31	14:04:00	14:04:00	2	F99
2026-05-19 14:13:19.872748	T12_0_33	16:00:00	16:00:00	1	F27
2026-05-19 14:13:19.872748	T12_0_33	16:04:00	16:04:00	2	F99
2026-05-19 14:13:19.872748	T12_0_35	18:00:00	18:00:00	1	F27
2026-05-19 14:13:19.872748	T12_0_35	18:04:00	18:04:00	2	F99
2026-05-19 14:13:19.872748	T12_1_26	05:30:00	05:30:00	1	F99
2026-05-19 14:13:19.872748	T12_1_26	05:34:00	05:34:00	2	F27
2026-05-19 14:13:19.872748	T12_1_28	07:00:00	07:00:00	1	F99
2026-05-19 14:13:19.872748	T12_1_28	07:04:00	07:04:00	2	F27
2026-05-19 14:13:19.872748	T12_1_30	09:00:00	09:00:00	1	F99
2026-05-19 14:13:19.872748	T12_1_30	09:04:00	09:04:00	2	F27
2026-05-19 14:13:19.872748	T12_1_32	14:00:00	14:00:00	1	F99
2026-05-19 14:13:19.872748	T12_1_32	14:04:00	14:04:00	2	F27
2026-05-19 14:13:19.872748	T12_1_34	16:00:00	16:00:00	1	F99
2026-05-19 14:13:19.872748	T12_1_34	16:04:00	16:04:00	2	F27
2026-05-19 14:13:19.872748	T12_1_36	18:00:00	18:00:00	1	F99
2026-05-19 14:13:19.872748	T12_1_36	18:04:00	18:04:00	2	F27
2026-05-19 14:13:19.872748	T13_0_37	05:30:00	05:30:00	1	F27
2026-05-19 14:13:19.872748	T13_0_37	05:34:00	05:34:00	2	F91
2026-05-19 14:13:19.872748	T13_0_39	07:00:00	07:00:00	1	F27
2026-05-19 14:13:19.872748	T13_0_39	07:04:00	07:04:00	2	F91
2026-05-19 14:13:19.872748	T13_0_41	09:00:00	09:00:00	1	F27
2026-05-19 14:13:19.872748	T13_0_41	09:04:00	09:04:00	2	F91
2026-05-19 14:13:19.872748	T13_0_43	14:00:00	14:00:00	1	F27
2026-05-19 14:13:19.872748	T13_0_43	14:04:00	14:04:00	2	F91
2026-05-19 14:13:19.872748	T13_0_45	16:00:00	16:00:00	1	F27
2026-05-19 14:13:19.872748	T13_0_45	16:04:00	16:04:00	2	F91
2026-05-19 14:13:19.872748	T13_0_47	18:00:00	18:00:00	1	F27
2026-05-19 14:13:19.872748	T13_0_47	18:04:00	18:04:00	2	F91
2026-05-19 14:13:19.872748	T13_1_38	05:30:00	05:30:00	1	F91
2026-05-19 14:13:19.872748	T13_1_38	05:34:00	05:34:00	2	F27
2026-05-19 14:13:19.872748	T13_1_40	07:00:00	07:00:00	1	F91
2026-05-19 14:13:19.872748	T13_1_40	07:04:00	07:04:00	2	F27
2026-05-19 14:13:19.872748	T13_1_42	09:00:00	09:00:00	1	F91
2026-05-19 14:13:19.872748	T13_1_42	09:04:00	09:04:00	2	F27
2026-05-19 14:13:19.872748	T13_1_44	14:00:00	14:00:00	1	F91
2026-05-19 14:13:19.872748	T13_1_44	14:04:00	14:04:00	2	F27
2026-05-19 14:13:19.872748	T13_1_46	16:00:00	16:00:00	1	F91
2026-05-19 14:13:19.872748	T13_1_46	16:04:00	16:04:00	2	F27
2026-05-19 14:13:19.872748	T13_1_48	18:00:00	18:00:00	1	F91
2026-05-19 14:13:19.872748	T13_1_48	18:04:00	18:04:00	2	F27
2026-05-19 14:13:19.872748	T14_0_49	05:30:00	05:30:00	1	F27
2026-05-19 14:13:19.872748	T14_0_49	05:38:00	05:38:00	2	F121
2026-05-19 14:13:19.872748	T14_0_51	07:00:00	07:00:00	1	F27
2026-05-19 14:13:19.872748	T14_0_51	07:08:00	07:08:00	2	F121
2026-05-19 14:13:19.872748	T14_0_53	09:00:00	09:00:00	1	F27
2026-05-19 14:13:19.872748	T14_0_53	09:08:00	09:08:00	2	F121
2026-05-19 14:13:19.872748	T14_0_55	14:00:00	14:00:00	1	F27
2026-05-19 14:13:19.872748	T14_0_55	14:08:00	14:08:00	2	F121
2026-05-19 14:13:19.872748	T14_0_57	16:00:00	16:00:00	1	F27
2026-05-19 14:13:19.872748	T14_0_57	16:08:00	16:08:00	2	F121
2026-05-19 14:13:19.872748	T14_1_50	05:30:00	05:30:00	1	F121
2026-05-19 14:13:19.872748	T14_1_50	05:38:00	05:38:00	2	F27
2026-05-19 14:13:19.872748	T14_1_52	07:00:00	07:00:00	1	F121
2026-05-19 14:13:19.872748	T14_1_52	07:08:00	07:08:00	2	F27
2026-05-19 14:13:19.872748	T14_1_54	09:00:00	09:00:00	1	F121
2026-05-19 14:13:19.872748	T14_1_54	09:08:00	09:08:00	2	F27
2026-05-19 14:13:19.872748	T14_1_56	14:00:00	14:00:00	1	F121
2026-05-19 14:13:19.872748	T14_1_56	14:08:00	14:08:00	2	F27
2026-05-19 14:13:19.872748	T14_1_58	16:00:00	16:00:00	1	F121
2026-05-19 14:13:19.872748	T14_1_58	16:08:00	16:08:00	2	F27
2026-05-19 14:13:19.872748	T16_0_65	04:00:00	04:00:00	1	F10
2026-05-19 14:13:19.872748	T16_0_65	04:08:00	04:08:00	2	F27
2026-05-19 14:13:19.872748	T16_0_65	04:15:00	04:15:00	3	F121
2026-05-19 14:13:19.872748	T16_0_67	07:00:00	07:00:00	1	F10
2026-05-19 14:13:19.872748	T16_0_67	07:08:00	07:08:00	2	F27
2026-05-19 14:13:19.872748	T16_0_67	07:15:00	07:15:00	3	F121
2026-05-19 14:13:19.872748	T16_1_66	04:00:00	04:00:00	1	F121
2026-05-19 14:13:19.872748	T16_1_66	04:07:00	04:07:00	2	F27
2026-05-19 14:13:19.872748	T16_1_66	04:15:00	04:15:00	3	F10
2026-05-19 14:13:19.872748	T16_1_68	07:00:00	07:00:00	1	F121
2026-05-19 14:13:19.872748	T16_1_68	07:07:00	07:07:00	2	F27
2026-05-19 14:13:19.872748	T16_1_68	07:15:00	07:15:00	3	F10
2026-05-19 14:13:19.872748	T17_0_71	17:00:00	17:00:00	1	F10
2026-05-19 14:13:19.872748	T17_0_71	17:10:00	17:10:00	2	F6
2026-05-19 14:13:19.872748	T17_0_71	17:20:00	17:20:00	3	F2
2026-05-19 14:13:19.872748	T17_0_71	17:45:00	17:45:00	4	F200
2026-05-19 14:13:19.872748	T17_1_70	07:00:00	07:00:00	1	F200
2026-05-19 14:13:19.872748	T17_1_70	07:25:00	07:25:00	2	F2
2026-05-19 14:13:19.872748	T17_1_70	07:35:00	07:35:00	3	F6
2026-05-19 14:13:19.872748	T17_1_70	07:45:00	07:45:00	4	F10
2026-05-19 14:13:19.872748	T19_0_77	06:00:00	06:00:00	1	F10
2026-05-19 14:13:19.872748	T19_0_77	06:10:00	06:10:00	2	F35
2026-05-19 14:13:19.872748	T19_1_78	06:00:00	06:00:00	1	F35
2026-05-19 14:13:19.872748	T19_1_78	06:10:00	06:10:00	2	F10
2026-05-19 14:13:19.872748	T24_0_102	13:00:00	13:00:00	1	F10
2026-05-19 14:13:19.872748	T24_0_102	13:30:00	13:30:00	2	F130
2026-05-19 14:13:19.872748	T24_1_103	13:00:00	13:00:00	1	F130
2026-05-19 14:13:19.872748	T24_1_103	13:30:00	13:30:00	2	F10
2026-05-19 14:13:19.872748	T25_0_104	06:30:00	06:30:00	1	F38
2026-05-19 14:13:19.872748	T25_0_104	06:40:00	06:40:00	2	F67
2026-05-19 14:13:19.872748	T25_0_106	10:00:00	10:00:00	1	F38
2026-05-19 14:13:19.872748	T25_0_106	10:10:00	10:10:00	2	F67
2026-05-19 14:13:19.872748	T25_0_108	15:01:00	15:01:00	1	F38
2026-05-19 14:13:19.872748	T25_0_108	15:11:00	15:11:00	2	F67
2026-05-19 14:13:19.872748	T25_1_105	06:30:00	06:30:00	1	F67
2026-05-19 14:13:19.872748	T25_1_105	06:40:00	06:40:00	2	F38
2026-05-19 14:13:19.872748	T25_1_107	10:00:00	10:00:00	1	F67
2026-05-19 14:13:19.872748	T25_1_107	10:10:00	10:10:00	2	F38
2026-05-19 14:13:19.872748	T25_1_109	15:01:00	15:01:00	1	F67
2026-05-19 14:13:19.872748	T25_1_109	15:11:00	15:11:00	2	F38
2026-05-19 14:13:19.872748	T27_0_116	06:00:00	06:00:00	1	F70
2026-05-19 14:13:19.872748	T27_0_116	06:02:00	06:02:00	2	F30
2026-05-19 14:13:19.872748	T27_0_118	07:00:00	07:00:00	1	F70
2026-05-19 14:13:19.872748	T27_0_118	07:02:00	07:02:00	2	F30
2026-05-19 14:13:19.872748	T27_0_120	09:00:00	09:00:00	1	F70
2026-05-19 14:13:19.872748	T27_0_120	09:02:00	09:02:00	2	F30
2026-05-19 14:13:19.872748	T27_1_117	06:00:00	06:00:00	1	F30
2026-05-19 14:13:19.872748	T27_1_117	06:02:00	06:02:00	2	F70
2026-05-19 14:13:19.872748	T27_1_119	07:00:00	07:00:00	1	F30
2026-05-19 14:13:19.872748	T27_1_119	07:02:00	07:02:00	2	F70
2026-05-19 14:13:19.872748	T27_1_121	09:00:00	09:00:00	1	F30
2026-05-19 14:13:19.872748	T27_1_121	09:02:00	09:02:00	2	F70
2026-05-19 14:13:19.872748	T28_0_122	06:00:00	06:00:00	1	F70
2026-05-19 14:13:19.872748	T28_0_122	06:02:00	06:02:00	2	F125
2026-05-19 14:13:19.872748	T28_0_124	07:00:00	07:00:00	1	F70
2026-05-19 14:13:19.872748	T28_0_124	07:02:00	07:02:00	2	F125
2026-05-19 14:13:19.872748	T28_0_126	09:00:00	09:00:00	1	F70
2026-05-19 14:13:19.872748	T28_0_126	09:02:00	09:02:00	2	F125
2026-05-19 14:13:19.872748	T28_1_123	06:00:00	06:00:00	1	F125
2026-05-19 14:13:19.872748	T28_1_123	06:02:00	06:02:00	2	F70
2026-05-19 14:13:19.872748	T28_1_125	07:00:00	07:00:00	1	F125
2026-05-19 14:13:19.872748	T28_1_125	07:02:00	07:02:00	2	F70
2026-05-19 14:13:19.872748	T28_1_127	09:00:00	09:00:00	1	F125
2026-05-19 14:13:19.872748	T28_1_127	09:02:00	09:02:00	2	F70
2026-05-19 14:13:19.872748	T29_0_128	06:00:00	06:00:00	1	F70
2026-05-19 14:13:19.872748	T29_0_128	06:02:00	06:02:00	2	F59
2026-05-19 14:13:19.872748	T29_0_130	07:00:00	07:00:00	1	F70
2026-05-19 14:13:19.872748	T29_0_130	07:02:00	07:02:00	2	F59
2026-05-19 14:13:19.872748	T29_0_132	09:00:00	09:00:00	1	F70
2026-05-19 14:13:19.872748	T29_0_132	09:02:00	09:02:00	2	F59
2026-05-19 14:13:19.872748	T29_1_129	06:00:00	06:00:00	1	F59
2026-05-19 14:13:19.872748	T29_1_129	06:02:00	06:02:00	2	F70
2026-05-19 14:13:19.872748	T29_1_131	07:00:00	07:00:00	1	F59
2026-05-19 14:13:19.872748	T29_1_131	07:02:00	07:02:00	2	F70
2026-05-19 14:13:19.872748	T29_1_133	09:00:00	09:00:00	1	F59
2026-05-19 14:13:19.872748	T29_1_133	09:02:00	09:02:00	2	F70
2026-05-19 14:13:19.872748	T30_0_134	06:00:00	06:00:00	1	F70
2026-05-19 14:13:19.872748	T30_0_134	06:10:00	06:10:00	2	F120
2026-05-19 14:13:19.872748	T30_0_134	06:25:00	06:25:00	3	F62
2026-05-19 14:13:19.872748	T30_0_136	06:00:00	06:00:00	1	F70
2026-05-19 14:13:19.872748	T30_0_136	06:10:00	06:10:00	2	F120
2026-05-19 14:13:19.872748	T30_0_136	06:25:00	06:25:00	3	F62
2026-05-19 14:13:19.872748	T30_0_138	13:00:00	13:00:00	1	F70
2026-05-19 14:13:19.872748	T30_0_138	13:10:00	13:10:00	2	F120
2026-05-19 14:13:19.872748	T30_0_138	13:25:00	13:25:00	3	F62
2026-05-19 14:13:19.872748	T30_1_135	06:00:00	06:00:00	1	F62
2026-05-19 14:13:19.872748	T30_1_135	06:15:00	06:15:00	2	F120
2026-05-19 14:13:19.872748	T30_1_135	06:25:00	06:25:00	3	F70
2026-05-19 14:13:19.872748	T30_1_137	06:00:00	06:00:00	1	F62
2026-05-19 14:13:19.872748	T30_1_137	06:15:00	06:15:00	2	F120
2026-05-19 14:13:19.872748	T30_1_137	06:25:00	06:25:00	3	F70
2026-05-19 14:13:19.872748	T30_1_139	13:00:00	13:00:00	1	F62
2026-05-19 14:13:19.872748	T30_1_139	13:15:00	13:15:00	2	F120
2026-05-19 14:13:19.872748	T30_1_139	13:25:00	13:25:00	3	F70
2026-05-19 14:13:19.872748	T31_0_140	18:00:00	18:00:00	1	F18
2026-05-19 14:13:19.872748	T31_0_140	19:40:00	19:40:00	2	F139
2026-05-19 14:13:19.872748	T31_0_140	20:00:00	20:00:00	3	F4
2026-05-19 14:13:19.872748	T33_0_142	06:30:00	06:30:00	1	F18
2026-05-19 14:13:19.872748	T33_0_142	06:50:00	06:50:00	2	F80
2026-05-19 14:13:19.872748	T33_0_144	10:30:00	10:30:00	1	F18
2026-05-19 14:13:19.872748	T33_0_144	10:50:00	10:50:00	2	F80
2026-05-19 14:13:19.872748	T33_0_146	16:00:00	16:00:00	1	F18
2026-05-19 14:13:19.872748	T33_0_146	16:20:00	16:20:00	2	F80
2026-05-19 14:13:19.872748	T33_1_143	06:30:00	06:30:00	1	F80
2026-05-19 14:13:19.872748	T33_1_143	06:50:00	06:50:00	2	F18
2026-05-19 14:13:19.872748	T33_1_145	10:30:00	10:30:00	1	F80
2026-05-19 14:13:19.872748	T33_1_145	10:50:00	10:50:00	2	F18
2026-05-19 14:13:19.872748	T33_1_147	16:00:00	16:00:00	1	F80
2026-05-19 14:13:19.872748	T33_1_147	16:20:00	16:20:00	2	F18
2026-05-19 14:13:19.872748	T34_0_187	05:30:00	05:30:00	1	F15
2026-05-19 14:13:19.872748	T34_0_187	06:00:00	06:00:00	2	F2
2026-05-19 14:13:19.872748	T34_0_183	06:30:00	06:30:00	1	F15
2026-05-19 14:13:19.872748	T34_0_183	07:00:00	07:00:00	2	F2
2026-05-19 14:13:19.872748	T34_0_191	06:30:00	06:30:00	1	F15
2026-05-19 14:13:19.872748	T34_0_191	07:00:00	07:00:00	2	F2
2026-05-19 14:13:19.872748	T36_0_193	06:30:00	06:30:00	1	F15
2026-05-19 14:13:19.872748	T36_0_193	07:10:00	07:10:00	2	F10
2026-05-19 14:13:19.872748	T36_1_196	16:30:00	16:30:00	1	F10
2026-05-19 14:13:19.872748	T36_1_196	17:10:00	17:10:00	2	F15
2026-05-19 14:13:19.872748	T37_0_197	07:00:00	07:00:00	1	F14
2026-05-19 14:13:19.872748	T37_0_197	07:20:00	07:20:00	2	F12
2026-05-19 14:13:19.872748	T37_0_197	07:25:00	07:25:00	3	F7
2026-05-19 14:13:19.872748	T37_0_197	07:30:00	07:30:00	4	F2
2026-05-19 14:13:19.872748	T37_1_200	17:00:00	17:00:00	1	F2
2026-05-19 14:13:19.872748	T37_1_200	17:05:00	17:05:00	2	F7
2026-05-19 14:13:19.872748	T37_1_200	17:10:00	17:10:00	3	F12
2026-05-19 14:13:19.872748	T37_1_200	17:30:00	17:30:00	4	F14
2026-05-19 14:13:19.872748	T38_0_201	06:30:00	06:30:00	1	F69
2026-05-19 14:13:19.872748	T38_0_201	06:40:00	06:40:00	2	F8
2026-05-19 14:13:19.872748	T38_0_203	09:00:00	09:00:00	1	F69
2026-05-19 14:13:19.872748	T38_0_203	09:10:00	09:10:00	2	F8
2026-05-19 14:13:19.872748	T38_1_204	09:00:00	09:00:00	1	F8
2026-05-19 14:13:19.872748	T38_1_204	09:10:00	09:10:00	2	F69
2026-05-19 14:13:19.872748	T38_1_206	15:30:00	15:30:00	1	F8
2026-05-19 14:13:19.872748	T38_1_206	15:40:00	15:40:00	2	F69
2026-05-19 14:13:19.872748	T40_0_213	07:00:00	07:00:00	1	F69
2026-05-19 14:13:19.872748	T40_0_213	07:25:00	07:25:00	2	F7
2026-05-19 14:13:19.872748	T40_0_213	07:30:00	07:30:00	3	F2
2026-05-19 14:13:19.872748	T40_1_216	17:30:00	17:30:00	1	F2
2026-05-19 14:13:19.872748	T40_1_216	17:35:00	17:35:00	2	F7
2026-05-19 14:13:19.872748	T40_1_216	18:00:00	18:00:00	3	F69
2026-05-19 14:13:19.872748	T41_0_217	06:00:00	06:00:00	1	F109
2026-05-19 14:13:19.872748	T41_0_217	06:07:00	06:07:00	2	F31
2026-05-19 14:13:19.872748	T41_0_219	11:00:00	11:00:00	1	F109
2026-05-19 14:13:19.872748	T41_0_219	11:07:00	11:07:00	2	F31
2026-05-19 14:13:19.872748	T41_1_218	06:00:00	06:00:00	1	F31
2026-05-19 14:13:19.872748	T41_1_218	06:07:00	06:07:00	2	F109
2026-05-19 14:13:19.872748	T41_1_220	11:00:00	11:00:00	1	F31
2026-05-19 14:13:19.872748	T41_1_220	11:07:00	11:07:00	2	F109
2026-05-19 14:13:19.872748	T43_0_227	06:00:00	06:00:00	1	F71
2026-05-19 14:13:19.872748	T43_0_227	06:05:00	06:05:00	2	F144
2026-05-19 14:13:19.872748	T43_0_229	12:00:00	12:00:00	1	F71
2026-05-19 14:13:19.872748	T43_0_229	12:05:00	12:05:00	2	F144
2026-05-19 14:13:19.872748	T43_0_231	15:00:00	15:00:00	1	F71
2026-05-19 14:13:19.872748	T43_0_231	15:05:00	15:05:00	2	F144
2026-05-19 14:13:19.872748	T43_1_228	06:00:00	06:00:00	1	F144
2026-05-19 14:13:19.872748	T43_1_228	06:05:00	06:05:00	2	F71
2026-05-19 14:13:19.872748	T43_1_230	12:00:00	12:00:00	1	F144
2026-05-19 14:13:19.872748	T43_1_230	12:05:00	12:05:00	2	F71
2026-05-19 14:13:19.872748	T43_1_232	15:00:00	15:00:00	1	F144
2026-05-19 14:13:19.872748	T43_1_232	15:05:00	15:05:00	2	F71
2026-05-19 14:13:19.872748	T44_0_233	03:00:00	03:00:00	1	F63
2026-05-19 14:13:19.872748	T44_0_233	03:07:00	03:07:00	2	F145
2026-05-19 14:13:19.872748	T44_0_243	05:30:00	05:30:00	1	F63
2026-05-19 14:13:19.872748	T44_0_243	05:37:00	05:37:00	2	F145
2026-05-19 14:13:19.872748	T44_0_235	07:00:00	07:00:00	1	F63
2026-05-19 14:13:19.872748	T44_0_235	07:07:00	07:07:00	2	F145
2026-05-19 14:13:19.872748	T44_0_245	10:00:00	10:00:00	1	F63
2026-05-19 14:13:19.872748	T44_0_245	10:07:00	10:07:00	2	F145
2026-05-19 14:13:19.872748	T44_0_237	11:00:00	11:00:00	1	F63
2026-05-19 14:13:19.872748	T44_0_237	11:07:00	11:07:00	2	F145
2026-05-19 14:13:19.872748	T44_0_247	13:00:00	13:00:00	1	F63
2026-05-19 14:13:19.872748	T44_0_247	13:07:00	13:07:00	2	F145
2026-05-19 14:13:19.872748	T44_0_239	16:00:00	16:00:00	1	F63
2026-05-19 14:13:19.872748	T44_0_239	16:07:00	16:07:00	2	F145
2026-05-19 14:13:19.872748	T44_0_241	19:00:00	19:00:00	1	F63
2026-05-19 14:13:19.872748	T44_0_241	19:07:00	19:07:00	2	F145
2026-05-19 14:13:19.872748	T44_1_234	03:00:00	03:00:00	1	F145
2026-05-19 14:13:19.872748	T44_1_234	03:07:00	03:07:00	2	F63
2026-05-19 14:13:19.872748	T44_1_244	05:30:00	05:30:00	1	F145
2026-05-19 14:13:19.872748	T44_1_244	05:37:00	05:37:00	2	F63
2026-05-19 14:13:19.872748	T44_1_236	07:00:00	07:00:00	1	F145
2026-05-19 14:13:19.872748	T44_1_236	07:07:00	07:07:00	2	F63
2026-05-19 14:13:19.872748	T44_1_246	10:00:00	10:00:00	1	F145
2026-05-19 14:13:19.872748	T44_1_246	10:07:00	10:07:00	2	F63
2026-05-19 14:13:19.872748	T44_1_238	11:00:00	11:00:00	1	F145
2026-05-19 14:13:19.872748	T44_1_238	11:07:00	11:07:00	2	F63
2026-05-19 14:13:19.872748	T44_1_248	13:00:00	13:00:00	1	F145
2026-05-19 14:13:19.872748	T44_1_248	13:07:00	13:07:00	2	F63
2026-05-19 14:13:19.872748	T44_1_240	16:00:00	16:00:00	1	F145
2026-05-19 14:13:19.872748	T44_1_240	16:07:00	16:07:00	2	F63
2026-05-19 14:13:19.872748	T44_1_242	19:00:00	19:00:00	1	F145
2026-05-19 14:13:19.872748	T44_1_242	19:07:00	19:07:00	2	F63
2026-05-19 14:13:19.872748	T45_0_249	06:30:00	06:30:00	1	F9
2026-05-19 14:13:19.872748	T45_0_249	07:07:00	07:07:00	2	F81
2026-05-19 14:13:19.872748	T45_1_250	06:30:00	06:30:00	1	F81
2026-05-19 14:13:19.872748	T45_1_250	07:07:00	07:07:00	2	F9
2026-05-19 14:13:19.872748	T46_0_251	06:30:00	06:30:00	1	F9
2026-05-19 14:13:19.872748	T46_0_251	07:10:00	07:10:00	2	F74
2026-05-19 14:13:19.872748	T46_1_252	06:30:00	06:30:00	1	F74
2026-05-19 14:13:19.872748	T46_1_252	07:10:00	07:10:00	2	F9
2026-05-19 14:13:19.872748	T47_0_255	13:00:00	13:00:00	1	F9
2026-05-19 14:13:19.872748	T47_0_255	13:45:00	13:45:00	2	F77
2026-05-19 14:13:19.872748	T47_1_254	08:00:00	08:00:00	1	F77
2026-05-19 14:13:19.872748	T47_1_254	08:45:00	08:45:00	2	F9
2026-05-19 14:13:19.872748	T48_0_257	06:30:00	06:30:00	1	F9
2026-05-19 14:13:19.872748	T48_0_257	07:10:00	07:10:00	2	F19
2026-05-19 14:13:19.872748	T48_0_259	06:30:00	06:30:00	1	F9
2026-05-19 14:13:19.872748	T48_0_259	07:10:00	07:10:00	2	F19
2026-05-19 14:13:19.872748	T48_1_258	06:30:00	06:30:00	1	F19
2026-05-19 14:13:19.872748	T48_1_258	07:10:00	07:10:00	2	F9
2026-05-19 14:13:19.872748	T48_1_260	06:30:00	06:30:00	1	F19
2026-05-19 14:13:19.872748	T48_1_260	07:10:00	07:10:00	2	F9
2026-05-19 14:13:19.872748	T49_0_265	06:30:00	06:30:00	1	F9
2026-05-19 14:13:19.872748	T49_0_265	07:00:00	07:00:00	2	F10
2026-05-19 14:13:19.872748	T49_0_265	07:20:00	07:20:00	3	F6
2026-05-19 14:13:19.872748	T49_0_261	07:30:00	07:30:00	1	F9
2026-05-19 14:13:19.872748	T49_0_261	08:00:00	08:00:00	2	F10
2026-05-19 14:13:19.872748	T49_0_261	08:20:00	08:20:00	3	F6
2026-05-19 14:13:19.872748	T49_1_266	06:30:00	06:30:00	1	F6
2026-05-19 14:13:19.872748	T49_1_266	06:50:00	06:50:00	2	F10
2026-05-19 14:13:19.872748	T49_1_266	07:20:00	07:20:00	3	F9
2026-05-19 14:13:19.872748	T49_1_264	17:00:00	17:00:00	1	F6
2026-05-19 14:13:19.872748	T49_1_264	17:20:00	17:20:00	2	F10
2026-05-19 14:13:19.872748	T49_1_264	17:50:00	17:50:00	3	F9
2026-05-19 14:13:19.872748	T50_0_267	06:30:00	06:30:00	1	F23
2026-05-19 14:13:19.872748	T50_0_267	06:32:00	06:32:00	2	F20
2026-05-19 14:13:19.872748	T50_1_268	06:30:00	06:30:00	1	F20
2026-05-19 14:13:19.872748	T50_1_268	06:32:00	06:32:00	2	F23
2026-05-19 14:13:19.872748	T53_0_277	06:30:00	06:30:00	1	F51
2026-05-19 14:13:19.872748	T53_0_277	06:32:00	06:32:00	2	F141
2026-05-19 14:13:19.872748	T53_0_279	12:00:00	12:00:00	1	F51
2026-05-19 14:13:19.872748	T53_0_279	12:02:00	12:02:00	2	F141
2026-05-19 14:13:19.872748	T53_0_281	14:00:00	14:00:00	1	F51
2026-05-19 14:13:19.872748	T53_0_281	14:02:00	14:02:00	2	F141
2026-05-19 14:13:19.872748	T53_1_278	06:30:00	06:30:00	1	F141
2026-05-19 14:13:19.872748	T53_1_278	06:32:00	06:32:00	2	F51
2026-05-19 14:13:19.872748	T53_1_280	12:00:00	12:00:00	1	F141
2026-05-19 14:13:19.872748	T53_1_280	12:02:00	12:02:00	2	F51
2026-05-19 14:13:19.872748	T53_1_282	14:00:00	14:00:00	1	F141
2026-05-19 14:13:19.872748	T53_1_282	14:02:00	14:02:00	2	F51
2026-05-19 14:13:19.872748	T54_0_283	06:00:00	06:00:00	1	F83
2026-05-19 14:13:19.872748	T54_0_283	06:03:00	06:03:00	2	F142
2026-05-19 14:13:19.872748	T54_0_291	06:00:00	06:00:00	1	F83
2026-05-19 14:13:19.872748	T54_0_291	06:03:00	06:03:00	2	F142
2026-05-19 14:13:19.872748	T54_0_285	08:00:00	08:00:00	1	F83
2026-05-19 14:13:19.872748	T54_0_285	08:03:00	08:03:00	2	F142
2026-05-19 14:13:19.872748	T54_0_293	08:00:00	08:00:00	1	F83
2026-05-19 14:13:19.872748	T54_0_293	08:03:00	08:03:00	2	F142
2026-05-19 14:13:19.872748	T54_0_287	13:00:00	13:00:00	1	F83
2026-05-19 14:13:19.872748	T54_0_287	13:03:00	13:03:00	2	F142
2026-05-19 14:13:19.872748	T54_0_289	15:00:00	15:00:00	1	F83
2026-05-19 14:13:19.872748	T54_0_289	15:03:00	15:03:00	2	F142
2026-05-19 14:13:19.872748	T54_1_292	06:00:00	06:00:00	1	F142
2026-05-19 14:13:19.872748	T54_1_292	06:03:00	06:03:00	2	F83
2026-05-19 14:13:19.872748	T54_1_284	06:00:00	06:00:00	1	F142
2026-05-19 14:13:19.872748	T54_1_284	06:03:00	06:03:00	2	F83
2026-05-19 14:13:19.872748	T54_1_294	08:00:00	08:00:00	1	F142
2026-05-19 14:13:19.872748	T54_1_294	08:03:00	08:03:00	2	F83
2026-05-19 14:13:19.872748	T54_1_286	08:00:00	08:00:00	1	F142
2026-05-19 14:13:19.872748	T54_1_286	08:03:00	08:03:00	2	F83
2026-05-19 14:13:19.872748	T54_1_288	13:00:00	13:00:00	1	F142
2026-05-19 14:13:19.872748	T54_1_288	13:03:00	13:03:00	2	F83
2026-05-19 14:13:19.872748	T54_1_290	15:00:00	15:00:00	1	F142
2026-05-19 14:13:19.872748	T54_1_290	15:03:00	15:03:00	2	F83
2026-05-19 14:13:19.872748	T63_0_323	06:00:00	06:00:00	1	F10
2026-05-19 14:13:19.872748	T63_0_323	06:09:00	06:09:00	2	F85
2026-05-19 14:13:19.872748	T63_0_325	08:00:00	08:00:00	1	F10
2026-05-19 14:13:19.872748	T63_0_325	08:09:00	08:09:00	2	F85
2026-05-19 14:13:19.872748	T63_0_327	10:00:00	10:00:00	1	F10
2026-05-19 14:13:19.872748	T63_0_327	10:09:00	10:09:00	2	F85
2026-05-19 14:13:19.872748	T63_0_329	14:00:00	14:00:00	1	F10
2026-05-19 14:13:19.872748	T63_0_329	14:09:00	14:09:00	2	F85
2026-05-19 14:13:19.872748	T63_0_331	16:00:00	16:00:00	1	F10
2026-05-19 14:13:19.872748	T63_0_331	16:09:00	16:09:00	2	F85
2026-05-19 14:13:19.872748	T63_1_324	06:00:00	06:00:00	1	F85
2026-05-19 14:13:19.872748	T63_1_324	06:09:00	06:09:00	2	F10
2026-05-19 14:13:19.872748	T63_1_326	08:00:00	08:00:00	1	F85
2026-05-19 14:13:19.872748	T63_1_326	08:09:00	08:09:00	2	F10
2026-05-19 14:13:19.872748	T63_1_328	10:00:00	10:00:00	1	F85
2026-05-19 14:13:19.872748	T63_1_328	10:09:00	10:09:00	2	F10
2026-05-19 14:13:19.872748	T63_1_330	14:00:00	14:00:00	1	F85
2026-05-19 14:13:19.872748	T63_1_330	14:09:00	14:09:00	2	F10
2026-05-19 14:13:19.872748	T63_1_332	16:00:00	16:00:00	1	F85
2026-05-19 14:13:19.872748	T63_1_332	16:09:00	16:09:00	2	F10
2026-05-19 14:13:19.872748	T64_0_333	06:30:00	06:30:00	1	F10
2026-05-19 14:13:19.872748	T64_0_333	06:40:00	06:40:00	2	F64
2026-05-19 14:13:19.872748	T64_0_333	06:50:00	06:50:00	3	F78
2026-05-19 14:13:19.872748	T64_0_333	07:05:00	07:05:00	4	F84
2026-05-19 14:13:19.872748	T64_0_335	13:00:00	13:00:00	1	F10
2026-05-19 14:13:19.872748	T64_0_335	13:10:00	13:10:00	2	F64
2026-05-19 14:13:19.872748	T64_0_335	13:20:00	13:20:00	3	F78
2026-05-19 14:13:19.872748	T64_0_335	13:35:00	13:35:00	4	F84
2026-05-19 14:13:19.872748	T64_0_337	16:00:00	16:00:00	1	F10
2026-05-19 14:13:19.872748	T64_0_337	16:10:00	16:10:00	2	F64
2026-05-19 14:13:19.872748	T64_0_337	16:20:00	16:20:00	3	F78
2026-05-19 14:13:19.872748	T64_0_337	16:35:00	16:35:00	4	F84
2026-05-19 14:13:19.872748	T64_1_334	06:30:00	06:30:00	1	F84
2026-05-19 14:13:19.872748	T64_1_334	06:45:00	06:45:00	2	F78
2026-05-19 14:13:19.872748	T64_1_334	06:55:00	06:55:00	3	F64
2026-05-19 14:13:19.872748	T64_1_334	07:05:00	07:05:00	4	F10
2026-05-19 14:13:19.872748	T64_1_336	13:00:00	13:00:00	1	F84
2026-05-19 14:13:19.872748	T64_1_336	13:15:00	13:15:00	2	F78
2026-05-19 14:13:19.872748	T64_1_336	13:25:00	13:25:00	3	F64
2026-05-19 14:13:19.872748	T64_1_336	13:35:00	13:35:00	4	F10
2026-05-19 14:13:19.872748	T64_1_338	16:00:00	16:00:00	1	F84
2026-05-19 14:13:19.872748	T64_1_338	16:15:00	16:15:00	2	F78
2026-05-19 14:13:19.872748	T64_1_338	16:25:00	16:25:00	3	F64
2026-05-19 14:13:19.872748	T64_1_338	16:35:00	16:35:00	4	F10
2026-05-19 14:13:19.872748	T65_0_349	06:00:00	06:00:00	1	F107
2026-05-19 14:13:19.872748	T65_0_349	06:15:00	06:15:00	2	F89
2026-05-19 14:13:19.872748	T65_0_349	06:20:00	06:20:00	3	F73
2026-05-19 14:13:19.872748	T65_0_349	06:22:00	06:22:00	4	F74
2026-05-19 14:13:19.872748	T65_0_349	06:27:00	06:27:00	5	F122
2026-05-19 14:13:19.872748	T65_0_349	06:30:00	06:30:00	6	F135
2026-05-19 14:13:19.872748	T65_0_349	06:32:00	06:32:00	7	F100
2026-05-19 14:13:19.872748	T65_0_349	06:35:00	06:35:00	8	F77
2026-05-19 14:13:19.872748	T65_0_339	06:00:00	06:00:00	1	F107
2026-05-19 14:13:19.872748	T65_0_339	06:15:00	06:15:00	2	F89
2026-05-19 14:13:19.872748	T65_0_339	06:20:00	06:20:00	3	F73
2026-05-19 14:13:19.872748	T65_0_339	06:22:00	06:22:00	4	F74
2026-05-19 14:13:19.872748	T65_0_339	06:27:00	06:27:00	5	F122
2026-05-19 14:13:19.872748	T65_0_339	06:30:00	06:30:00	6	F135
2026-05-19 14:13:19.872748	T65_0_339	06:32:00	06:32:00	7	F100
2026-05-19 14:13:19.872748	T65_0_339	06:35:00	06:35:00	8	F77
2026-05-19 14:13:19.872748	T65_0_341	08:00:00	08:00:00	1	F107
2026-05-19 14:13:19.872748	T65_0_341	08:15:00	08:15:00	2	F89
2026-05-19 14:13:19.872748	T65_0_341	08:20:00	08:20:00	3	F73
2026-05-19 14:13:19.872748	T65_0_341	08:22:00	08:22:00	4	F74
2026-05-19 14:13:19.872748	T65_0_341	08:27:00	08:27:00	5	F122
2026-05-19 14:13:19.872748	T65_0_341	08:30:00	08:30:00	6	F135
2026-05-19 14:13:19.872748	T65_0_341	08:32:00	08:32:00	7	F100
2026-05-19 14:13:19.872748	T65_0_341	08:35:00	08:35:00	8	F77
2026-05-19 14:13:19.872748	T65_0_351	12:00:00	12:00:00	1	F107
2026-05-19 14:13:19.872748	T65_0_351	12:15:00	12:15:00	2	F89
2026-05-19 14:13:19.872748	T65_0_351	12:20:00	12:20:00	3	F73
2026-05-19 14:13:19.872748	T65_0_351	12:22:00	12:22:00	4	F74
2026-05-19 14:13:19.872748	T65_0_351	12:27:00	12:27:00	5	F122
2026-05-19 14:13:19.872748	T65_0_351	12:30:00	12:30:00	6	F135
2026-05-19 14:13:19.872748	T65_0_351	12:32:00	12:32:00	7	F100
2026-05-19 14:13:19.872748	T65_0_351	12:35:00	12:35:00	8	F77
2026-05-19 14:13:19.872748	T65_0_343	12:00:00	12:00:00	1	F107
2026-05-19 14:13:19.872748	T65_0_343	12:15:00	12:15:00	2	F89
2026-05-19 14:13:19.872748	T65_0_343	12:20:00	12:20:00	3	F73
2026-05-19 14:13:19.872748	T65_0_343	12:22:00	12:22:00	4	F74
2026-05-19 14:13:19.872748	T65_0_343	12:27:00	12:27:00	5	F122
2026-05-19 14:13:19.872748	T65_0_343	12:30:00	12:30:00	6	F135
2026-05-19 14:13:19.872748	T65_0_343	12:32:00	12:32:00	7	F100
2026-05-19 14:13:19.872748	T65_0_343	12:35:00	12:35:00	8	F77
2026-05-19 14:13:19.872748	T65_0_345	14:00:00	14:00:00	1	F107
2026-05-19 14:13:19.872748	T65_0_345	14:15:00	14:15:00	2	F89
2026-05-19 14:13:19.872748	T65_0_345	14:20:00	14:20:00	3	F73
2026-05-19 14:13:19.872748	T65_0_345	14:22:00	14:22:00	4	F74
2026-05-19 14:13:19.872748	T65_0_345	14:27:00	14:27:00	5	F122
2026-05-19 14:13:19.872748	T65_0_345	14:30:00	14:30:00	6	F135
2026-05-19 14:13:19.872748	T65_0_345	14:32:00	14:32:00	7	F100
2026-05-19 14:13:19.872748	T65_0_345	14:35:00	14:35:00	8	F77
2026-05-19 14:13:19.872748	T65_0_353	15:00:00	15:00:00	1	F107
2026-05-19 14:13:19.872748	T65_0_353	15:15:00	15:15:00	2	F89
2026-05-19 14:13:19.872748	T65_0_353	15:20:00	15:20:00	3	F73
2026-05-19 14:13:19.872748	T65_0_353	15:22:00	15:22:00	4	F74
2026-05-19 14:13:19.872748	T65_0_353	15:27:00	15:27:00	5	F122
2026-05-19 14:13:19.872748	T65_0_353	15:30:00	15:30:00	6	F135
2026-05-19 14:13:19.872748	T65_0_353	15:32:00	15:32:00	7	F100
2026-05-19 14:13:19.872748	T65_0_353	15:35:00	15:35:00	8	F77
2026-05-19 14:13:19.872748	T65_0_347	17:00:00	17:00:00	1	F107
2026-05-19 14:13:19.872748	T65_0_347	17:15:00	17:15:00	2	F89
2026-05-19 14:13:19.872748	T65_0_347	17:20:00	17:20:00	3	F73
2026-05-19 14:13:19.872748	T65_0_347	17:22:00	17:22:00	4	F74
2026-05-19 14:13:19.872748	T65_0_347	17:27:00	17:27:00	5	F122
2026-05-19 14:13:19.872748	T65_0_347	17:30:00	17:30:00	6	F135
2026-05-19 14:13:19.872748	T65_0_347	17:32:00	17:32:00	7	F100
2026-05-19 14:13:19.872748	T65_0_347	17:35:00	17:35:00	8	F77
2026-05-19 14:13:19.872748	T65_1_350	06:00:00	06:00:00	1	F77
2026-05-19 14:13:19.872748	T65_1_350	06:03:00	06:03:00	2	F100
2026-05-19 14:13:19.872748	T65_1_350	06:05:00	06:05:00	3	F135
2026-05-19 14:13:19.872748	T65_1_350	06:08:00	06:08:00	4	F122
2026-05-19 14:13:19.872748	T65_1_350	06:13:00	06:13:00	5	F74
2026-05-19 14:13:19.872748	T65_1_350	06:15:00	06:15:00	6	F73
2026-05-19 14:13:19.872748	T65_1_350	06:20:00	06:20:00	7	F89
2026-05-19 14:13:19.872748	T65_1_350	06:35:00	06:35:00	8	F107
2026-05-19 14:13:19.872748	T65_1_340	06:00:00	06:00:00	1	F77
2026-05-19 14:13:19.872748	T65_1_340	06:03:00	06:03:00	2	F100
2026-05-19 14:13:19.872748	T65_1_340	06:05:00	06:05:00	3	F135
2026-05-19 14:13:19.872748	T65_1_340	06:08:00	06:08:00	4	F122
2026-05-19 14:13:19.872748	T65_1_340	06:13:00	06:13:00	5	F74
2026-05-19 14:13:19.872748	T65_1_340	06:15:00	06:15:00	6	F73
2026-05-19 14:13:19.872748	T65_1_340	06:20:00	06:20:00	7	F89
2026-05-19 14:13:19.872748	T65_1_340	06:35:00	06:35:00	8	F107
2026-05-19 14:13:19.872748	T65_1_342	08:00:00	08:00:00	1	F77
2026-05-19 14:13:19.872748	T65_1_342	08:03:00	08:03:00	2	F100
2026-05-19 14:13:19.872748	T65_1_342	08:05:00	08:05:00	3	F135
2026-05-19 14:13:19.872748	T65_1_342	08:08:00	08:08:00	4	F122
2026-05-19 14:13:19.872748	T65_1_342	08:13:00	08:13:00	5	F74
2026-05-19 14:13:19.872748	T65_1_342	08:15:00	08:15:00	6	F73
2026-05-19 14:13:19.872748	T65_1_342	08:20:00	08:20:00	7	F89
2026-05-19 14:13:19.872748	T65_1_342	08:35:00	08:35:00	8	F107
2026-05-19 14:13:19.872748	T65_1_344	12:00:00	12:00:00	1	F77
2026-05-19 14:13:19.872748	T65_1_344	12:03:00	12:03:00	2	F100
2026-05-19 14:13:19.872748	T65_1_344	12:05:00	12:05:00	3	F135
2026-05-19 14:13:19.872748	T65_1_344	12:08:00	12:08:00	4	F122
2026-05-19 14:13:19.872748	T65_1_344	12:13:00	12:13:00	5	F74
2026-05-19 14:13:19.872748	T65_1_344	12:15:00	12:15:00	6	F73
2026-05-19 14:13:19.872748	T65_1_344	12:20:00	12:20:00	7	F89
2026-05-19 14:13:19.872748	T65_1_344	12:35:00	12:35:00	8	F107
2026-05-19 14:13:19.872748	T65_1_352	12:00:00	12:00:00	1	F77
2026-05-19 14:13:19.872748	T65_1_352	12:03:00	12:03:00	2	F100
2026-05-19 14:13:19.872748	T65_1_352	12:05:00	12:05:00	3	F135
2026-05-19 14:13:19.872748	T65_1_352	12:08:00	12:08:00	4	F122
2026-05-19 14:13:19.872748	T65_1_352	12:13:00	12:13:00	5	F74
2026-05-19 14:13:19.872748	T65_1_352	12:15:00	12:15:00	6	F73
2026-05-19 14:13:19.872748	T65_1_352	12:20:00	12:20:00	7	F89
2026-05-19 14:13:19.872748	T65_1_352	12:35:00	12:35:00	8	F107
2026-05-19 14:13:19.872748	T65_1_346	14:00:00	14:00:00	1	F77
2026-05-19 14:13:19.872748	T65_1_346	14:03:00	14:03:00	2	F100
2026-05-19 14:13:19.872748	T65_1_346	14:05:00	14:05:00	3	F135
2026-05-19 14:13:19.872748	T65_1_346	14:08:00	14:08:00	4	F122
2026-05-19 14:13:19.872748	T65_1_346	14:13:00	14:13:00	5	F74
2026-05-19 14:13:19.872748	T65_1_346	14:15:00	14:15:00	6	F73
2026-05-19 14:13:19.872748	T65_1_346	14:20:00	14:20:00	7	F89
2026-05-19 14:13:19.872748	T65_1_346	14:35:00	14:35:00	8	F107
2026-05-19 14:13:19.872748	T65_1_354	15:00:00	15:00:00	1	F77
2026-05-19 14:13:19.872748	T65_1_354	15:03:00	15:03:00	2	F100
2026-05-19 14:13:19.872748	T65_1_354	15:05:00	15:05:00	3	F135
2026-05-19 14:13:19.872748	T65_1_354	15:08:00	15:08:00	4	F122
2026-05-19 14:13:19.872748	T65_1_354	15:13:00	15:13:00	5	F74
2026-05-19 14:13:19.872748	T65_1_354	15:15:00	15:15:00	6	F73
2026-05-19 14:13:19.872748	T65_1_354	15:20:00	15:20:00	7	F89
2026-05-19 14:13:19.872748	T65_1_354	15:35:00	15:35:00	8	F107
2026-05-19 14:13:19.872748	T65_1_348	17:00:00	17:00:00	1	F77
2026-05-19 14:13:19.872748	T65_1_348	17:03:00	17:03:00	2	F100
2026-05-19 14:13:19.872748	T65_1_348	17:05:00	17:05:00	3	F135
2026-05-19 14:13:19.872748	T65_1_348	17:08:00	17:08:00	4	F122
2026-05-19 14:13:19.872748	T65_1_348	17:13:00	17:13:00	5	F74
2026-05-19 14:13:19.872748	T65_1_348	17:15:00	17:15:00	6	F73
2026-05-19 14:13:19.872748	T65_1_348	17:20:00	17:20:00	7	F89
2026-05-19 14:13:19.872748	T65_1_348	17:35:00	17:35:00	8	F107
2026-05-19 14:13:19.872748	T66_0_355	06:00:00	06:00:00	1	F89
2026-05-19 14:13:19.872748	T66_0_355	06:15:00	06:15:00	2	F107
2026-05-19 14:13:19.872748	T66_0_357	09:00:00	09:00:00	1	F89
2026-05-19 14:13:19.872748	T66_0_357	09:15:00	09:15:00	2	F107
2026-05-19 14:13:19.872748	T66_0_359	12:00:00	12:00:00	1	F89
2026-05-19 14:13:19.872748	T66_0_359	12:15:00	12:15:00	2	F107
2026-05-19 14:13:19.872748	T66_1_356	06:00:00	06:00:00	1	F107
2026-05-19 14:13:19.872748	T66_1_356	06:15:00	06:15:00	2	F89
2026-05-19 14:13:19.872748	T66_1_358	09:00:00	09:00:00	1	F107
2026-05-19 14:13:19.872748	T66_1_358	09:15:00	09:15:00	2	F89
2026-05-19 14:13:19.872748	T66_1_360	12:00:00	12:00:00	1	F107
2026-05-19 14:13:19.872748	T66_1_360	12:15:00	12:15:00	2	F89
2026-05-19 14:13:19.872748	T67_0_361	06:00:00	06:00:00	1	F73
2026-05-19 14:13:19.872748	T67_0_361	06:05:00	06:05:00	2	F89
2026-05-19 14:13:19.872748	T67_0_361	06:20:00	06:20:00	3	F107
2026-05-19 14:13:19.872748	T67_0_363	09:00:00	09:00:00	1	F73
2026-05-19 14:13:19.872748	T67_0_363	09:05:00	09:05:00	2	F89
2026-05-19 14:13:19.872748	T67_0_363	09:20:00	09:20:00	3	F107
2026-05-19 14:13:19.872748	T67_0_365	12:00:00	12:00:00	1	F73
2026-05-19 14:13:19.872748	T67_0_365	12:05:00	12:05:00	2	F89
2026-05-19 14:13:19.872748	T67_0_365	12:20:00	12:20:00	3	F107
2026-05-19 14:13:19.872748	T67_1_362	06:00:00	06:00:00	1	F107
2026-05-19 14:13:19.872748	T67_1_362	06:15:00	06:15:00	2	F89
2026-05-19 14:13:19.872748	T67_1_362	06:20:00	06:20:00	3	F73
2026-05-19 14:13:19.872748	T67_1_364	09:00:00	09:00:00	1	F107
2026-05-19 14:13:19.872748	T67_1_364	09:15:00	09:15:00	2	F89
2026-05-19 14:13:19.872748	T67_1_364	09:20:00	09:20:00	3	F73
2026-05-19 14:13:19.872748	T67_1_366	12:00:00	12:00:00	1	F107
2026-05-19 14:13:19.872748	T67_1_366	12:15:00	12:15:00	2	F89
2026-05-19 14:13:19.872748	T67_1_366	12:20:00	12:20:00	3	F73
2026-05-19 14:13:19.872748	T68_0_367	06:00:00	06:00:00	1	F74
2026-05-19 14:13:19.872748	T68_0_367	06:05:00	06:05:00	2	F89
2026-05-19 14:13:19.872748	T68_0_367	06:20:00	06:20:00	3	F107
2026-05-19 14:13:19.872748	T68_0_369	09:00:00	09:00:00	1	F74
2026-05-19 14:13:19.872748	T68_0_369	09:05:00	09:05:00	2	F89
2026-05-19 14:13:19.872748	T68_0_369	09:20:00	09:20:00	3	F107
2026-05-19 14:13:19.872748	T68_0_371	12:00:00	12:00:00	1	F74
2026-05-19 14:13:19.872748	T68_0_371	12:05:00	12:05:00	2	F89
2026-05-19 14:13:19.872748	T68_0_371	12:20:00	12:20:00	3	F107
2026-05-19 14:13:19.872748	T68_1_368	06:00:00	06:00:00	1	F107
2026-05-19 14:13:19.872748	T68_1_368	06:15:00	06:15:00	2	F89
2026-05-19 14:13:19.872748	T68_1_368	06:20:00	06:20:00	3	F74
2026-05-19 14:13:19.872748	T68_1_370	09:00:00	09:00:00	1	F107
2026-05-19 14:13:19.872748	T68_1_370	09:15:00	09:15:00	2	F89
2026-05-19 14:13:19.872748	T68_1_370	09:20:00	09:20:00	3	F74
2026-05-19 14:13:19.872748	T68_1_372	12:00:00	12:00:00	1	F107
2026-05-19 14:13:19.872748	T68_1_372	12:15:00	12:15:00	2	F89
2026-05-19 14:13:19.872748	T68_1_372	12:20:00	12:20:00	3	F74
2026-05-19 14:13:19.872748	T71_0_376	06:00:00	06:00:00	1	F60
2026-05-19 14:13:19.872748	T71_0_376	06:01:00	06:01:00	2	F114
2026-05-19 14:13:19.872748	T71_0_376	06:04:00	06:04:00	3	F62
2026-05-19 14:13:19.872748	T71_0_376	06:06:00	06:06:00	4	F44
2026-05-19 14:13:19.872748	T71_0_376	06:08:00	06:08:00	5	F119
2026-05-19 14:13:19.872748	T71_0_376	06:11:00	06:11:00	6	F93
2026-05-19 14:13:19.872748	T71_0_376	06:14:00	06:14:00	7	F120
2026-05-19 14:13:19.872748	T71_0_376	06:17:00	06:17:00	8	F59
2026-05-19 14:13:19.872748	T71_0_376	06:18:00	06:18:00	9	F30
2026-05-19 14:13:19.872748	T71_0_376	06:19:00	06:19:00	10	F125
2026-05-19 14:13:19.872748	T71_0_376	06:20:00	06:20:00	11	F70
2026-05-19 14:13:19.872748	T71_0_384	06:00:00	06:00:00	1	F60
2026-05-19 14:13:19.872748	T71_0_384	06:01:00	06:01:00	2	F114
2026-05-19 14:13:19.872748	T71_0_384	06:04:00	06:04:00	3	F62
2026-05-19 14:13:19.872748	T71_0_384	06:06:00	06:06:00	4	F44
2026-05-19 14:13:19.872748	T71_0_384	06:08:00	06:08:00	5	F119
2026-05-19 14:13:19.872748	T71_0_384	06:11:00	06:11:00	6	F93
2026-05-19 14:13:19.872748	T71_0_384	06:14:00	06:14:00	7	F120
2026-05-19 14:13:19.872748	T71_0_384	06:17:00	06:17:00	8	F59
2026-05-19 14:13:19.872748	T71_0_384	06:18:00	06:18:00	9	F30
2026-05-19 14:13:19.872748	T71_0_384	06:19:00	06:19:00	10	F125
2026-05-19 14:13:19.872748	T71_0_384	06:20:00	06:20:00	11	F70
2026-05-19 14:13:19.872748	T71_0_378	09:00:00	09:00:00	1	F60
2026-05-19 14:13:19.872748	T71_0_378	09:01:00	09:01:00	2	F114
2026-05-19 14:13:19.872748	T71_0_378	09:04:00	09:04:00	3	F62
2026-05-19 14:13:19.872748	T71_0_378	09:06:00	09:06:00	4	F44
2026-05-19 14:13:19.872748	T71_0_378	09:08:00	09:08:00	5	F119
2026-05-19 14:13:19.872748	T71_0_378	09:11:00	09:11:00	6	F93
2026-05-19 14:13:19.872748	T71_0_378	09:14:00	09:14:00	7	F120
2026-05-19 14:13:19.872748	T71_0_378	09:17:00	09:17:00	8	F59
2026-05-19 14:13:19.872748	T71_0_378	09:18:00	09:18:00	9	F30
2026-05-19 14:13:19.872748	T71_0_378	09:19:00	09:19:00	10	F125
2026-05-19 14:13:19.872748	T71_0_378	09:20:00	09:20:00	11	F70
2026-05-19 14:13:19.872748	T71_0_386	13:00:00	13:00:00	1	F60
2026-05-19 14:13:19.872748	T71_0_386	13:01:00	13:01:00	2	F114
2026-05-19 14:13:19.872748	T71_0_386	13:04:00	13:04:00	3	F62
2026-05-19 14:13:19.872748	T71_0_386	13:06:00	13:06:00	4	F44
2026-05-19 14:13:19.872748	T71_0_386	13:08:00	13:08:00	5	F119
2026-05-19 14:13:19.872748	T71_0_386	13:11:00	13:11:00	6	F93
2026-05-19 14:13:19.872748	T71_0_386	13:14:00	13:14:00	7	F120
2026-05-19 14:13:19.872748	T71_0_386	13:17:00	13:17:00	8	F59
2026-05-19 14:13:19.872748	T71_0_386	13:18:00	13:18:00	9	F30
2026-05-19 14:13:19.872748	T71_0_386	13:19:00	13:19:00	10	F125
2026-05-19 14:13:19.872748	T71_0_386	13:20:00	13:20:00	11	F70
2026-05-19 14:13:19.872748	T71_0_380	14:00:00	14:00:00	1	F60
2026-05-19 14:13:19.872748	T71_0_380	14:01:00	14:01:00	2	F114
2026-05-19 14:13:19.872748	T71_0_380	14:04:00	14:04:00	3	F62
2026-05-19 14:13:19.872748	T71_0_380	14:06:00	14:06:00	4	F44
2026-05-19 14:13:19.872748	T71_0_380	14:08:00	14:08:00	5	F119
2026-05-19 14:13:19.872748	T71_0_380	14:11:00	14:11:00	6	F93
2026-05-19 14:13:19.872748	T71_0_380	14:14:00	14:14:00	7	F120
2026-05-19 14:13:19.872748	T71_0_380	14:17:00	14:17:00	8	F59
2026-05-19 14:13:19.872748	T71_0_380	14:18:00	14:18:00	9	F30
2026-05-19 14:13:19.872748	T71_0_380	14:19:00	14:19:00	10	F125
2026-05-19 14:13:19.872748	T71_0_380	14:20:00	14:20:00	11	F70
2026-05-19 14:13:19.872748	T71_0_382	17:00:00	17:00:00	1	F60
2026-05-19 14:13:19.872748	T71_0_382	17:01:00	17:01:00	2	F114
2026-05-19 14:13:19.872748	T71_0_382	17:04:00	17:04:00	3	F62
2026-05-19 14:13:19.872748	T71_0_382	17:06:00	17:06:00	4	F44
2026-05-19 14:13:19.872748	T71_0_382	17:08:00	17:08:00	5	F119
2026-05-19 14:13:19.872748	T71_0_382	17:11:00	17:11:00	6	F93
2026-05-19 14:13:19.872748	T71_0_382	17:14:00	17:14:00	7	F120
2026-05-19 14:13:19.872748	T71_0_382	17:17:00	17:17:00	8	F59
2026-05-19 14:13:19.872748	T71_0_382	17:18:00	17:18:00	9	F30
2026-05-19 14:13:19.872748	T71_0_382	17:19:00	17:19:00	10	F125
2026-05-19 14:13:19.872748	T71_0_382	17:20:00	17:20:00	11	F70
2026-05-19 14:13:19.872748	T71_1_385	06:00:00	06:00:00	1	F70
2026-05-19 14:13:19.872748	T71_1_385	06:01:00	06:01:00	2	F125
2026-05-19 14:13:19.872748	T71_1_385	06:02:00	06:02:00	3	F30
2026-05-19 14:13:19.872748	T71_1_385	06:03:00	06:03:00	4	F59
2026-05-19 14:13:19.872748	T71_1_385	06:06:00	06:06:00	5	F120
2026-05-19 14:13:19.872748	T71_1_385	06:09:00	06:09:00	6	F93
2026-05-19 14:13:19.872748	T71_1_385	06:12:00	06:12:00	7	F119
2026-05-19 14:13:19.872748	T71_1_385	06:14:00	06:14:00	8	F44
2026-05-19 14:13:19.872748	T71_1_385	06:16:00	06:16:00	9	F62
2026-05-19 14:13:19.872748	T71_1_385	06:19:00	06:19:00	10	F114
2026-05-19 14:13:19.872748	T71_1_385	06:20:00	06:20:00	11	F60
2026-05-19 14:13:19.872748	T71_1_377	06:00:00	06:00:00	1	F70
2026-05-19 14:13:19.872748	T71_1_377	06:01:00	06:01:00	2	F125
2026-05-19 14:13:19.872748	T71_1_377	06:02:00	06:02:00	3	F30
2026-05-19 14:13:19.872748	T71_1_377	06:03:00	06:03:00	4	F59
2026-05-19 14:13:19.872748	T71_1_377	06:06:00	06:06:00	5	F120
2026-05-19 14:13:19.872748	T71_1_377	06:09:00	06:09:00	6	F93
2026-05-19 14:13:19.872748	T71_1_377	06:12:00	06:12:00	7	F119
2026-05-19 14:13:19.872748	T71_1_377	06:14:00	06:14:00	8	F44
2026-05-19 14:13:19.872748	T71_1_377	06:16:00	06:16:00	9	F62
2026-05-19 14:13:19.872748	T71_1_377	06:19:00	06:19:00	10	F114
2026-05-19 14:13:19.872748	T71_1_377	06:20:00	06:20:00	11	F60
2026-05-19 14:13:19.872748	T71_1_379	09:00:00	09:00:00	1	F70
2026-05-19 14:13:19.872748	T71_1_379	09:01:00	09:01:00	2	F125
2026-05-19 14:13:19.872748	T71_1_379	09:02:00	09:02:00	3	F30
2026-05-19 14:13:19.872748	T71_1_379	09:03:00	09:03:00	4	F59
2026-05-19 14:13:19.872748	T71_1_379	09:06:00	09:06:00	5	F120
2026-05-19 14:13:19.872748	T71_1_379	09:09:00	09:09:00	6	F93
2026-05-19 14:13:19.872748	T71_1_379	09:12:00	09:12:00	7	F119
2026-05-19 14:13:19.872748	T71_1_379	09:14:00	09:14:00	8	F44
2026-05-19 14:13:19.872748	T71_1_379	09:16:00	09:16:00	9	F62
2026-05-19 14:13:19.872748	T71_1_379	09:19:00	09:19:00	10	F114
2026-05-19 14:13:19.872748	T71_1_379	09:20:00	09:20:00	11	F60
2026-05-19 14:13:19.872748	T71_1_387	13:00:00	13:00:00	1	F70
2026-05-19 14:13:19.872748	T71_1_387	13:01:00	13:01:00	2	F125
2026-05-19 14:13:19.872748	T71_1_387	13:02:00	13:02:00	3	F30
2026-05-19 14:13:19.872748	T71_1_387	13:03:00	13:03:00	4	F59
2026-05-19 14:13:19.872748	T71_1_387	13:06:00	13:06:00	5	F120
2026-05-19 14:13:19.872748	T71_1_387	13:09:00	13:09:00	6	F93
2026-05-19 14:13:19.872748	T71_1_387	13:12:00	13:12:00	7	F119
2026-05-19 14:13:19.872748	T71_1_387	13:14:00	13:14:00	8	F44
2026-05-19 14:13:19.872748	T71_1_387	13:16:00	13:16:00	9	F62
2026-05-19 14:13:19.872748	T71_1_387	13:19:00	13:19:00	10	F114
2026-05-19 14:13:19.872748	T71_1_387	13:20:00	13:20:00	11	F60
2026-05-19 14:13:19.872748	T71_1_381	14:00:00	14:00:00	1	F70
2026-05-19 14:13:19.872748	T71_1_381	14:01:00	14:01:00	2	F125
2026-05-19 14:13:19.872748	T71_1_381	14:02:00	14:02:00	3	F30
2026-05-19 14:13:19.872748	T71_1_381	14:03:00	14:03:00	4	F59
2026-05-19 14:13:19.872748	T71_1_381	14:06:00	14:06:00	5	F120
2026-05-19 14:13:19.872748	T71_1_381	14:09:00	14:09:00	6	F93
2026-05-19 14:13:19.872748	T71_1_381	14:12:00	14:12:00	7	F119
2026-05-19 14:13:19.872748	T71_1_381	14:14:00	14:14:00	8	F44
2026-05-19 14:13:19.872748	T71_1_381	14:16:00	14:16:00	9	F62
2026-05-19 14:13:19.872748	T71_1_381	14:19:00	14:19:00	10	F114
2026-05-19 14:13:19.872748	T71_1_381	14:20:00	14:20:00	11	F60
2026-05-19 14:13:19.872748	T71_1_383	17:00:00	17:00:00	1	F70
2026-05-19 14:13:19.872748	T71_1_383	17:01:00	17:01:00	2	F125
2026-05-19 14:13:19.872748	T71_1_383	17:02:00	17:02:00	3	F30
2026-05-19 14:13:19.872748	T71_1_383	17:03:00	17:03:00	4	F59
2026-05-19 14:13:19.872748	T71_1_383	17:06:00	17:06:00	5	F120
2026-05-19 14:13:19.872748	T71_1_383	17:09:00	17:09:00	6	F93
2026-05-19 14:13:19.872748	T71_1_383	17:12:00	17:12:00	7	F119
2026-05-19 14:13:19.872748	T71_1_383	17:14:00	17:14:00	8	F44
2026-05-19 14:13:19.872748	T71_1_383	17:16:00	17:16:00	9	F62
2026-05-19 14:13:19.872748	T71_1_383	17:19:00	17:19:00	10	F114
2026-05-19 14:13:19.872748	T71_1_383	17:20:00	17:20:00	11	F60
2026-05-19 14:13:19.872748	T72_0_388	08:00:00	08:00:00	1	F7
2026-05-19 14:13:19.872748	T72_0_388	08:45:00	08:45:00	2	F200
2026-05-19 14:13:19.872748	T72_0_390	12:00:00	12:00:00	1	F7
2026-05-19 14:13:19.872748	T72_0_390	12:45:00	12:45:00	2	F200
2026-05-19 14:13:19.872748	T72_0_392	16:00:00	16:00:00	1	F7
2026-05-19 14:13:19.872748	T72_0_392	16:45:00	16:45:00	2	F200
2026-05-19 14:13:19.872748	T72_1_389	08:00:00	08:00:00	1	F200
2026-05-19 14:13:19.872748	T72_1_389	08:45:00	08:45:00	2	F7
2026-05-19 14:13:19.872748	T72_1_391	12:00:00	12:00:00	1	F200
2026-05-19 14:13:19.872748	T72_1_391	12:45:00	12:45:00	2	F7
2026-05-19 14:13:19.872748	T72_1_393	16:00:00	16:00:00	1	F200
2026-05-19 14:13:19.872748	T72_1_393	16:45:00	16:45:00	2	F7
2026-05-19 14:13:19.872748	T73_0_918	17:30:00	17:30:00	1	F7
2026-05-19 14:13:19.872748	T73_0_918	18:05:00	18:05:00	2	F3
2026-05-19 14:13:19.872748	T73_1_917	06:30:00	06:30:00	1	F3
2026-05-19 14:13:19.872748	T73_1_917	07:05:00	07:05:00	2	F7
2026-05-19 14:13:19.872748	T74_0_920	17:30:00	17:30:00	1	F7
2026-05-19 14:13:19.872748	T74_0_920	18:00:00	18:00:00	2	F31
2026-05-19 14:13:19.872748	T74_1_919	06:30:00	06:30:00	1	F31
2026-05-19 14:13:19.872748	T74_1_919	07:00:00	07:00:00	2	F7
2026-05-19 14:13:19.872748	T75_0_406	08:00:00	08:00:00	1	F5
2026-05-19 14:13:19.872748	T75_0_406	08:05:00	08:05:00	2	F1
2026-05-19 14:13:19.872748	T75_0_406	08:40:00	08:40:00	3	F3
2026-05-19 14:13:19.872748	T75_0_408	12:00:00	12:00:00	1	F5
2026-05-19 14:13:19.872748	T75_0_408	12:05:00	12:05:00	2	F1
2026-05-19 14:13:19.872748	T75_0_408	12:40:00	12:40:00	3	F3
2026-05-19 14:13:19.872748	T75_0_410	16:00:00	16:00:00	1	F5
2026-05-19 14:13:19.872748	T75_0_410	16:05:00	16:05:00	2	F1
2026-05-19 14:13:19.872748	T75_0_410	16:40:00	16:40:00	3	F3
2026-05-19 14:13:19.872748	T75_1_407	08:00:00	08:00:00	1	F3
2026-05-19 14:13:19.872748	T75_1_407	08:35:00	08:35:00	2	F1
2026-05-19 14:13:19.872748	T75_1_407	08:40:00	08:40:00	3	F5
2026-05-19 14:13:19.872748	T75_1_409	12:00:00	12:00:00	1	F3
2026-05-19 14:13:19.872748	T75_1_409	12:35:00	12:35:00	2	F1
2026-05-19 14:13:19.872748	T75_1_409	12:40:00	12:40:00	3	F5
2026-05-19 14:13:19.872748	T75_1_411	16:00:00	16:00:00	1	F3
2026-05-19 14:13:19.872748	T75_1_411	16:35:00	16:35:00	2	F1
2026-05-19 14:13:19.872748	T75_1_411	16:40:00	16:40:00	3	F5
2026-05-19 14:13:19.872748	T76_0_654	06:30:00	06:30:00	1	F5
2026-05-19 14:13:19.872748	T76_0_654	06:35:00	06:35:00	2	F6
2026-05-19 14:13:19.872748	T76_0_656	07:00:00	07:00:00	1	F5
2026-05-19 14:13:19.872748	T76_0_656	07:05:00	07:05:00	2	F6
2026-05-19 14:13:19.872748	T76_0_658	09:00:00	09:00:00	1	F5
2026-05-19 14:13:19.872748	T76_0_658	09:05:00	09:05:00	2	F6
2026-05-19 14:13:19.872748	T76_0_660	17:00:00	17:00:00	1	F5
2026-05-19 14:13:19.872748	T76_0_660	17:05:00	17:05:00	2	F6
2026-05-19 14:13:19.872748	T76_1_655	06:30:00	06:30:00	1	F6
2026-05-19 14:13:19.872748	T76_1_655	06:35:00	06:35:00	2	F5
2026-05-19 14:13:19.872748	T76_1_657	07:00:00	07:00:00	1	F6
2026-05-19 14:13:19.872748	T76_1_657	07:05:00	07:05:00	2	F5
2026-05-19 14:13:19.872748	T76_1_659	09:00:00	09:00:00	1	F6
2026-05-19 14:13:19.872748	T76_1_659	09:05:00	09:05:00	2	F5
2026-05-19 14:13:19.872748	T76_1_661	17:00:00	17:00:00	1	F6
2026-05-19 14:13:19.872748	T76_1_661	17:05:00	17:05:00	2	F5
2026-05-19 14:13:19.872748	T77_0_418	06:00:00	06:00:00	1	F36
2026-05-19 14:13:19.872748	T77_0_418	06:30:00	06:30:00	2	F101
2026-05-19 14:13:19.872748	T77_0_420	10:00:00	10:00:00	1	F36
2026-05-19 14:13:19.872748	T77_0_420	10:30:00	10:30:00	2	F101
2026-05-19 14:13:19.872748	T77_0_422	16:00:00	16:00:00	1	F36
2026-05-19 14:13:19.872748	T77_0_422	16:30:00	16:30:00	2	F101
2026-05-19 14:13:19.872748	T77_1_419	06:00:00	06:00:00	1	F101
2026-05-19 14:13:19.872748	T77_1_419	06:30:00	06:30:00	2	F36
2026-05-19 14:13:19.872748	T77_1_421	10:00:00	10:00:00	1	F101
2026-05-19 14:13:19.872748	T77_1_421	10:30:00	10:30:00	2	F36
2026-05-19 14:13:19.872748	T77_1_423	16:00:00	16:00:00	1	F101
2026-05-19 14:13:19.872748	T77_1_423	16:30:00	16:30:00	2	F36
2026-05-19 14:13:19.872748	T89_0_483	17:30:00	17:30:00	1	F200
2026-05-19 14:13:19.872748	T89_0_483	17:40:00	17:40:00	2	F69
2026-05-19 14:13:19.872748	T89_1_482	06:30:00	06:30:00	1	F69
2026-05-19 14:13:19.872748	T89_1_482	06:40:00	06:40:00	2	F200
2026-05-19 14:13:19.872748	T90_0_484	07:00:00	07:00:00	1	F200
2026-05-19 14:13:19.872748	T90_0_484	07:40:00	07:40:00	2	F2
2026-05-19 14:13:19.872748	T90_1_485	17:30:00	17:30:00	1	F2
2026-05-19 14:13:19.872748	T90_1_485	18:10:00	18:10:00	2	F200
2026-05-19 14:13:19.872748	T91_0_487	17:30:00	17:30:00	1	F200
2026-05-19 14:13:19.872748	T91_0_487	17:45:00	17:45:00	2	F58
2026-05-19 14:13:19.872748	T91_1_486	06:30:00	06:30:00	1	F58
2026-05-19 14:13:19.872748	T91_1_486	06:45:00	06:45:00	2	F200
2026-05-19 14:13:19.872748	T92_0_488	06:30:00	06:30:00	1	F200
2026-05-19 14:13:19.872748	T92_0_488	06:35:00	06:35:00	2	F86
2026-05-19 14:13:19.872748	T92_1_489	06:30:00	06:30:00	1	F86
2026-05-19 14:13:19.872748	T92_1_489	06:35:00	06:35:00	2	F200
2026-05-19 14:13:19.872748	T94_0_492	06:00:00	06:00:00	1	F86
2026-05-19 14:13:19.872748	T94_0_492	06:02:00	06:02:00	2	F152
2026-05-19 14:13:19.872748	T94_1_493	06:00:00	06:00:00	1	F152
2026-05-19 14:13:19.872748	T94_1_493	06:02:00	06:02:00	2	F86
2026-05-19 14:13:19.872748	T95_0_494	12:00:00	12:00:00	1	F46
2026-05-19 14:13:19.872748	T95_0_494	14:30:00	14:30:00	2	F153
2026-05-19 14:13:19.872748	T96_0_495	16:30:00	16:30:00	1	F46
2026-05-19 14:13:19.872748	T96_0_495	18:20:00	18:20:00	2	F154
2026-05-19 14:13:19.872748	T97_0_496	13:30:00	13:30:00	1	F46
2026-05-19 14:13:19.872748	T97_0_496	14:30:00	14:30:00	2	F17
2026-05-19 14:13:19.872748	T98_0_497	08:00:00	08:00:00	1	F46
2026-05-19 14:13:19.872748	T98_0_497	08:20:00	08:20:00	2	F155
2026-05-19 14:13:19.872748	T98_0_499	11:00:00	11:00:00	1	F46
2026-05-19 14:13:19.872748	T98_0_499	11:20:00	11:20:00	2	F155
2026-05-19 14:13:19.872748	T98_1_498	08:00:00	08:00:00	1	F155
2026-05-19 14:13:19.872748	T98_1_498	08:20:00	08:20:00	2	F46
2026-05-19 14:13:19.872748	T98_1_500	11:00:00	11:00:00	1	F155
2026-05-19 14:13:19.872748	T98_1_500	11:20:00	11:20:00	2	F46
2026-05-19 14:13:19.872748	T103_0_509	06:30:00	06:30:00	1	F58
2026-05-19 14:13:19.872748	T103_0_509	07:10:00	07:10:00	2	F1
2026-05-19 14:13:19.872748	T103_0_509	07:20:00	07:20:00	3	F6
2026-05-19 14:13:19.872748	T107_0_513	07:00:00	07:00:00	1	F42
2026-05-19 14:13:19.872748	T107_0_513	07:30:00	07:30:00	2	F7
2026-05-19 14:13:19.872748	T107_0_513	08:05:00	08:05:00	3	F6
2026-05-19 14:13:19.872748	T108_0_519	06:30:00	06:30:00	1	F92
2026-05-19 14:13:19.872748	T108_0_519	06:55:00	06:55:00	2	F10
2026-05-19 14:13:19.872748	T108_0_519	07:10:00	07:10:00	3	F6
2026-05-19 14:13:19.872748	T108_0_521	10:30:00	10:30:00	1	F92
2026-05-19 14:13:19.872748	T108_0_521	10:55:00	10:55:00	2	F10
2026-05-19 14:13:19.872748	T108_0_521	11:10:00	11:10:00	3	F6
2026-05-19 14:13:19.872748	T108_1_520	06:30:00	06:30:00	1	F6
2026-05-19 14:13:19.872748	T108_1_520	06:45:00	06:45:00	2	F10
2026-05-19 14:13:19.872748	T108_1_520	07:10:00	07:10:00	3	F92
2026-05-19 14:13:19.872748	T108_1_522	10:30:00	10:30:00	1	F6
2026-05-19 14:13:19.872748	T108_1_522	10:45:00	10:45:00	2	F10
2026-05-19 14:13:19.872748	T108_1_522	11:10:00	11:10:00	3	F92
2026-05-19 14:13:19.872748	T108_1_523	15:30:00	15:30:00	1	F6
2026-05-19 14:13:19.872748	T108_1_523	15:45:00	15:45:00	2	F10
2026-05-19 14:13:19.872748	T108_1_523	16:10:00	16:10:00	3	F92
2026-05-19 14:13:19.872748	T109_0_524	06:30:00	06:30:00	1	F92
2026-05-19 14:13:19.872748	T109_0_524	06:50:00	06:50:00	2	F101
2026-05-19 14:13:19.872748	T109_0_526	10:30:00	10:30:00	1	F92
2026-05-19 14:13:19.872748	T109_0_526	10:50:00	10:50:00	2	F101
2026-05-19 14:13:19.872748	T109_1_525	06:30:00	06:30:00	1	F101
2026-05-19 14:13:19.872748	T109_1_525	06:50:00	06:50:00	2	F92
2026-05-19 14:13:19.872748	T109_1_527	10:30:00	10:30:00	1	F101
2026-05-19 14:13:19.872748	T109_1_527	10:50:00	10:50:00	2	F92
2026-05-19 14:13:19.872748	T109_1_528	15:30:00	15:30:00	1	F101
2026-05-19 14:13:19.872748	T109_1_528	15:50:00	15:50:00	2	F92
2026-05-19 14:13:19.872748	T111_0_530	07:00:00	07:00:00	1	F107
2026-05-19 14:13:19.872748	T111_0_530	07:15:00	07:15:00	2	F89
2026-05-19 14:13:19.872748	T111_0_530	07:20:00	07:20:00	3	F77
2026-05-19 14:13:19.872748	T111_0_532	10:30:00	10:30:00	1	F107
2026-05-19 14:13:19.872748	T111_0_532	10:45:00	10:45:00	2	F89
2026-05-19 14:13:19.872748	T111_0_532	10:50:00	10:50:00	3	F77
2026-05-19 14:13:19.872748	T111_0_534	16:00:00	16:00:00	1	F107
2026-05-19 14:13:19.872748	T111_0_534	16:15:00	16:15:00	2	F89
2026-05-19 14:13:19.872748	T111_0_534	16:20:00	16:20:00	3	F77
2026-05-19 14:13:19.872748	T111_1_531	07:00:00	07:00:00	1	F77
2026-05-19 14:13:19.872748	T111_1_531	07:05:00	07:05:00	2	F89
2026-05-19 14:13:19.872748	T111_1_531	07:20:00	07:20:00	3	F107
2026-05-19 14:13:19.872748	T111_1_533	10:30:00	10:30:00	1	F77
2026-05-19 14:13:19.872748	T111_1_533	10:35:00	10:35:00	2	F89
2026-05-19 14:13:19.872748	T111_1_533	10:50:00	10:50:00	3	F107
2026-05-19 14:13:19.872748	T111_1_535	16:00:00	16:00:00	1	F77
2026-05-19 14:13:19.872748	T111_1_535	16:05:00	16:05:00	2	F89
2026-05-19 14:13:19.872748	T111_1_535	16:20:00	16:20:00	3	F107
2026-05-19 14:13:19.872748	T112_0_536	08:00:00	08:00:00	1	F107
2026-05-19 14:13:19.872748	T112_0_536	08:30:00	08:30:00	2	F60
2026-05-19 14:13:19.872748	T112_1_537	08:00:00	08:00:00	1	F60
2026-05-19 14:13:19.872748	T112_1_537	08:30:00	08:30:00	2	F107
2026-05-19 14:13:19.872748	T113_0_538	07:00:00	07:00:00	1	F107
2026-05-19 14:13:19.872748	T113_0_538	07:25:00	07:25:00	2	F74
2026-05-19 14:13:19.872748	T113_0_540	10:30:00	10:30:00	1	F107
2026-05-19 14:13:19.872748	T113_0_540	10:55:00	10:55:00	2	F74
2026-05-19 14:13:19.872748	T113_0_542	16:00:00	16:00:00	1	F107
2026-05-19 14:13:19.872748	T113_0_542	16:25:00	16:25:00	2	F74
2026-05-19 14:13:19.872748	T113_1_539	07:00:00	07:00:00	1	F74
2026-05-19 14:13:19.872748	T113_1_539	07:25:00	07:25:00	2	F107
2026-05-19 14:13:19.872748	T113_1_541	10:30:00	10:30:00	1	F74
2026-05-19 14:13:19.872748	T113_1_541	10:55:00	10:55:00	2	F107
2026-05-19 14:13:19.872748	T113_1_543	16:00:00	16:00:00	1	F74
2026-05-19 14:13:19.872748	T113_1_543	16:25:00	16:25:00	2	F107
2026-05-19 14:13:19.872748	T115_0_552	07:00:00	07:00:00	1	F107
2026-05-19 14:13:19.872748	T115_0_552	07:15:00	07:15:00	2	F19
2026-05-19 14:13:19.872748	T115_0_554	10:30:00	10:30:00	1	F107
2026-05-19 14:13:19.872748	T115_0_554	10:45:00	10:45:00	2	F19
2026-05-19 14:13:19.872748	T115_0_556	16:00:00	16:00:00	1	F107
2026-05-19 14:13:19.872748	T115_0_556	16:15:00	16:15:00	2	F19
2026-05-19 14:13:19.872748	T115_0_558	19:00:00	19:00:00	1	F107
2026-05-19 14:13:19.872748	T115_0_558	19:15:00	19:15:00	2	F19
2026-05-19 14:13:19.872748	T115_1_553	07:00:00	07:00:00	1	F19
2026-05-19 14:13:19.872748	T115_1_553	07:15:00	07:15:00	2	F107
2026-05-19 14:13:19.872748	T115_1_555	10:30:00	10:30:00	1	F19
2026-05-19 14:13:19.872748	T115_1_555	10:45:00	10:45:00	2	F107
2026-05-19 14:13:19.872748	T115_1_557	16:00:00	16:00:00	1	F19
2026-05-19 14:13:19.872748	T115_1_557	16:15:00	16:15:00	2	F107
2026-05-19 14:13:19.872748	T115_1_559	19:00:00	19:00:00	1	F19
2026-05-19 14:13:19.872748	T115_1_559	19:15:00	19:15:00	2	F107
2026-05-19 14:13:19.872748	T116_0_560	06:30:00	06:30:00	1	F92
2026-05-19 14:13:19.872748	T116_0_560	07:35:00	07:35:00	2	F13
2026-05-19 14:13:19.872748	T116_0_560	08:45:00	08:45:00	3	F4
2026-05-19 14:13:19.872748	T116_1_561	06:30:00	06:30:00	1	F4
2026-05-19 14:13:19.872748	T116_1_561	07:40:00	07:40:00	2	F13
2026-05-19 14:13:19.872748	T116_1_561	08:45:00	08:45:00	3	F92
2026-05-19 14:13:19.872748	T121_0_592	06:30:00	06:30:00	1	F36
2026-05-19 14:13:19.872748	T121_0_592	06:50:00	06:50:00	2	F101
2026-05-19 14:13:19.872748	T121_0_592	07:05:00	07:05:00	3	F92
2026-05-19 14:13:19.872748	T121_0_594	10:00:00	10:00:00	1	F36
2026-05-19 14:13:19.872748	T121_0_594	10:20:00	10:20:00	2	F101
2026-05-19 14:13:19.872748	T121_0_594	10:35:00	10:35:00	3	F92
2026-05-19 14:13:19.872748	T121_0_596	16:00:00	16:00:00	1	F36
2026-05-19 14:13:19.872748	T121_0_596	16:20:00	16:20:00	2	F101
2026-05-19 14:13:19.872748	T121_0_596	16:35:00	16:35:00	3	F92
2026-05-19 14:13:19.872748	T121_1_593	06:30:00	06:30:00	1	F92
2026-05-19 14:13:19.872748	T121_1_593	06:45:00	06:45:00	2	F101
2026-05-19 14:13:19.872748	T121_1_593	07:05:00	07:05:00	3	F36
2026-05-19 14:13:19.872748	T121_1_595	10:00:00	10:00:00	1	F92
2026-05-19 14:13:19.872748	T121_1_595	10:15:00	10:15:00	2	F101
2026-05-19 14:13:19.872748	T121_1_595	10:35:00	10:35:00	3	F36
2026-05-19 14:13:19.872748	T121_1_597	16:00:00	16:00:00	1	F92
2026-05-19 14:13:19.872748	T121_1_597	16:15:00	16:15:00	2	F101
2026-05-19 14:13:19.872748	T121_1_597	16:35:00	16:35:00	3	F36
2026-05-19 14:13:19.872748	T122_0_604	06:30:00	06:30:00	1	F36
2026-05-19 14:13:19.872748	T122_0_604	06:45:00	06:45:00	2	F121
2026-05-19 14:13:19.872748	T122_0_604	07:00:00	07:00:00	3	F10
2026-05-19 14:13:19.872748	T122_0_606	10:00:00	10:00:00	1	F36
2026-05-19 14:13:19.872748	T122_0_606	10:15:00	10:15:00	2	F121
2026-05-19 14:13:19.872748	T122_0_606	10:30:00	10:30:00	3	F10
2026-05-19 14:13:19.872748	T122_0_608	16:00:00	16:00:00	1	F36
2026-05-19 14:13:19.872748	T122_0_608	16:15:00	16:15:00	2	F121
2026-05-19 14:13:19.872748	T122_0_608	16:30:00	16:30:00	3	F10
2026-05-19 14:13:19.872748	T122_1_605	06:30:00	06:30:00	1	F10
2026-05-19 14:13:19.872748	T122_1_605	06:45:00	06:45:00	2	F121
2026-05-19 14:13:19.872748	T122_1_605	07:00:00	07:00:00	3	F36
2026-05-19 14:13:19.872748	T122_1_607	10:00:00	10:00:00	1	F10
2026-05-19 14:13:19.872748	T122_1_607	10:15:00	10:15:00	2	F121
2026-05-19 14:13:19.872748	T122_1_607	10:30:00	10:30:00	3	F36
2026-05-19 14:13:19.872748	T122_1_609	16:00:00	16:00:00	1	F10
2026-05-19 14:13:19.872748	T122_1_609	16:15:00	16:15:00	2	F121
2026-05-19 14:13:19.872748	T122_1_609	16:30:00	16:30:00	3	F36
2026-05-19 14:13:19.872748	T123_0_610	07:00:00	07:00:00	1	F92
2026-05-19 14:13:19.872748	T123_0_610	07:20:00	07:20:00	2	F70
2026-05-19 14:13:19.872748	T123_0_612	10:00:00	10:00:00	1	F92
2026-05-19 14:13:19.872748	T123_0_612	10:20:00	10:20:00	2	F70
2026-05-19 14:13:19.872748	T123_0_614	16:00:00	16:00:00	1	F92
2026-05-19 14:13:19.872748	T123_0_614	16:20:00	16:20:00	2	F70
2026-05-19 14:13:19.872748	T123_1_611	07:00:00	07:00:00	1	F70
2026-05-19 14:13:19.872748	T123_1_611	07:20:00	07:20:00	2	F92
2026-05-19 14:13:19.872748	T123_1_613	10:00:00	10:00:00	1	F70
2026-05-19 14:13:19.872748	T123_1_613	10:20:00	10:20:00	2	F92
2026-05-19 14:13:19.872748	T123_1_615	16:00:00	16:00:00	1	F70
2026-05-19 14:13:19.872748	T123_1_615	16:20:00	16:20:00	2	F92
2026-05-19 14:13:19.872748	T124_0_616	07:00:00	07:00:00	1	F6
2026-05-19 14:13:19.872748	T124_0_616	07:10:00	07:10:00	2	F1
2026-05-19 14:13:19.872748	T124_0_616	07:40:00	07:40:00	3	F3
2026-05-19 14:13:19.872748	T124_0_618	10:00:00	10:00:00	1	F6
2026-05-19 14:13:19.872748	T124_0_618	10:10:00	10:10:00	2	F1
2026-05-19 14:13:19.872748	T124_0_618	10:40:00	10:40:00	3	F3
2026-05-19 14:13:19.872748	T124_0_620	16:00:00	16:00:00	1	F6
2026-05-19 14:13:19.872748	T124_0_620	16:10:00	16:10:00	2	F1
2026-05-19 14:13:19.872748	T124_0_620	16:40:00	16:40:00	3	F3
2026-05-19 14:13:19.872748	T124_1_617	07:00:00	07:00:00	1	F3
2026-05-19 14:13:19.872748	T124_1_617	07:30:00	07:30:00	2	F1
2026-05-19 14:13:19.872748	T124_1_617	07:40:00	07:40:00	3	F6
2026-05-19 14:13:19.872748	T124_1_619	10:00:00	10:00:00	1	F3
2026-05-19 14:13:19.872748	T124_1_619	10:30:00	10:30:00	2	F1
2026-05-19 14:13:19.872748	T124_1_619	10:40:00	10:40:00	3	F6
2026-05-19 14:13:19.872748	T124_1_621	16:00:00	16:00:00	1	F3
2026-05-19 14:13:19.872748	T124_1_621	16:30:00	16:30:00	2	F1
2026-05-19 14:13:19.872748	T124_1_621	16:40:00	16:40:00	3	F6
2026-05-19 14:13:19.872748	T125_0_622	07:00:00	07:00:00	1	F6
2026-05-19 14:13:19.872748	T125_0_622	07:10:00	07:10:00	2	F106
2026-05-19 14:13:19.872748	T125_0_622	07:19:00	07:19:00	3	F130
2026-05-19 14:13:19.872748	T125_0_624	10:00:00	10:00:00	1	F6
2026-05-19 14:13:19.872748	T125_0_624	10:10:00	10:10:00	2	F106
2026-05-19 14:13:19.872748	T125_0_624	10:19:00	10:19:00	3	F130
2026-05-19 14:13:19.872748	T125_0_626	16:00:00	16:00:00	1	F6
2026-05-19 14:13:19.872748	T125_0_626	16:10:00	16:10:00	2	F106
2026-05-19 14:13:19.872748	T125_0_626	16:19:00	16:19:00	3	F130
2026-05-19 14:13:19.872748	T125_1_623	07:00:00	07:00:00	1	F130
2026-05-19 14:13:19.872748	T125_1_623	07:09:00	07:09:00	2	F106
2026-05-19 14:13:19.872748	T125_1_623	07:19:00	07:19:00	3	F6
2026-05-19 14:13:19.872748	T125_1_625	10:00:00	10:00:00	1	F130
2026-05-19 14:13:19.872748	T125_1_625	10:09:00	10:09:00	2	F106
2026-05-19 14:13:19.872748	T125_1_625	10:19:00	10:19:00	3	F6
2026-05-19 14:13:19.872748	T125_1_627	16:00:00	16:00:00	1	F130
2026-05-19 14:13:19.872748	T125_1_627	16:09:00	16:09:00	2	F106
2026-05-19 14:13:19.872748	T125_1_627	16:19:00	16:19:00	3	F6
2026-05-19 14:13:19.872748	T126_0_806	06:00:00	06:00:00	1	F6
2026-05-19 14:13:19.872748	T126_0_806	08:00:00	08:00:00	2	F13
2026-05-19 14:13:19.872748	T126_0_806	09:00:00	09:00:00	3	F4
2026-05-19 14:13:19.872748	T128_0_632	06:30:00	06:30:00	1	F6
2026-05-19 14:13:19.872748	T128_0_632	06:55:00	06:55:00	2	F10
2026-05-19 14:13:19.872748	T128_1_633	06:30:00	06:30:00	1	F10
2026-05-19 14:13:19.872748	T128_1_633	06:55:00	06:55:00	2	F6
2026-05-19 14:13:19.872748	T129_0_827	07:00:00	07:00:00	1	F6
2026-05-19 14:13:19.872748	T129_0_827	07:25:00	07:25:00	2	F121
2026-05-19 14:13:19.872748	T129_0_829	10:30:00	10:30:00	1	F6
2026-05-19 14:13:19.872748	T129_0_829	10:55:00	10:55:00	2	F121
2026-05-19 14:13:19.872748	T129_0_831	17:00:00	17:00:00	1	F6
2026-05-19 14:13:19.872748	T129_0_831	17:25:00	17:25:00	2	F121
2026-05-19 14:13:19.872748	T129_1_828	07:00:00	07:00:00	1	F121
2026-05-19 14:13:19.872748	T129_1_828	07:25:00	07:25:00	2	F6
2026-05-19 14:13:19.872748	T129_1_830	10:30:00	10:30:00	1	F121
2026-05-19 14:13:19.872748	T129_1_830	10:55:00	10:55:00	2	F6
2026-05-19 14:13:19.872748	T129_1_832	17:00:00	17:00:00	1	F121
2026-05-19 14:13:19.872748	T129_1_832	17:25:00	17:25:00	2	F6
2026-05-19 14:13:19.872748	T131_0_638	05:00:00	05:00:00	1	F124
2026-05-19 14:13:19.872748	T131_0_638	05:07:00	05:07:00	2	F104
2026-05-19 14:13:19.872748	T131_0_640	09:00:00	09:00:00	1	F124
2026-05-19 14:13:19.872748	T131_0_640	09:07:00	09:07:00	2	F104
2026-05-19 14:13:19.872748	T131_0_642	17:00:00	17:00:00	1	F124
2026-05-19 14:13:19.872748	T131_0_642	17:07:00	17:07:00	2	F104
2026-05-19 14:13:19.872748	T131_0_644	19:00:00	19:00:00	1	F124
2026-05-19 14:13:19.872748	T131_0_644	19:07:00	19:07:00	2	F104
2026-05-19 14:13:19.872748	T131_1_639	05:00:00	05:00:00	1	F104
2026-05-19 14:13:19.872748	T131_1_639	05:07:00	05:07:00	2	F124
2026-05-19 14:13:19.872748	T131_1_641	09:00:00	09:00:00	1	F104
2026-05-19 14:13:19.872748	T131_1_641	09:07:00	09:07:00	2	F124
2026-05-19 14:13:19.872748	T131_1_643	17:00:00	17:00:00	1	F104
2026-05-19 14:13:19.872748	T131_1_643	17:07:00	17:07:00	2	F124
2026-05-19 14:13:19.872748	T131_1_645	19:00:00	19:00:00	1	F104
2026-05-19 14:13:19.872748	T131_1_645	19:07:00	19:07:00	2	F124
2026-05-19 14:13:19.872748	T132_0_646	05:00:00	05:00:00	1	F102
2026-05-19 14:13:19.872748	T132_0_646	05:07:00	05:07:00	2	F104
2026-05-19 14:13:19.872748	T132_0_648	09:00:00	09:00:00	1	F102
2026-05-19 14:13:19.872748	T132_0_648	09:07:00	09:07:00	2	F104
2026-05-19 14:13:19.872748	T132_0_650	17:00:00	17:00:00	1	F102
2026-05-19 14:13:19.872748	T132_0_650	17:07:00	17:07:00	2	F104
2026-05-19 14:13:19.872748	T132_0_652	19:00:00	19:00:00	1	F102
2026-05-19 14:13:19.872748	T132_0_652	19:07:00	19:07:00	2	F104
2026-05-19 14:13:19.872748	T132_1_647	05:00:00	05:00:00	1	F104
2026-05-19 14:13:19.872748	T132_1_647	05:07:00	05:07:00	2	F102
2026-05-19 14:13:19.872748	T132_1_649	09:00:00	09:00:00	1	F104
2026-05-19 14:13:19.872748	T132_1_649	09:07:00	09:07:00	2	F102
2026-05-19 14:13:19.872748	T132_1_651	17:00:00	17:00:00	1	F104
2026-05-19 14:13:19.872748	T132_1_651	17:07:00	17:07:00	2	F102
2026-05-19 14:13:19.872748	T132_1_653	19:00:00	19:00:00	1	F104
2026-05-19 14:13:19.872748	T132_1_653	19:07:00	19:07:00	2	F102
2026-05-19 14:13:19.872748	T135_0_678	05:00:00	05:00:00	1	F105
2026-05-19 14:13:19.872748	T135_0_678	05:05:00	05:05:00	2	F147
2026-05-19 14:13:19.872748	T135_0_680	09:00:00	09:00:00	1	F105
2026-05-19 14:13:19.872748	T135_0_680	09:05:00	09:05:00	2	F147
2026-05-19 14:13:19.872748	T135_0_682	17:00:00	17:00:00	1	F105
2026-05-19 14:13:19.872748	T135_0_682	17:05:00	17:05:00	2	F147
2026-05-19 14:13:19.872748	T135_0_684	19:00:00	19:00:00	1	F105
2026-05-19 14:13:19.872748	T135_0_684	19:05:00	19:05:00	2	F147
2026-05-19 14:13:19.872748	T135_1_679	05:00:00	05:00:00	1	F147
2026-05-19 14:13:19.872748	T135_1_679	05:05:00	05:05:00	2	F105
2026-05-19 14:13:19.872748	T135_1_681	09:00:00	09:00:00	1	F147
2026-05-19 14:13:19.872748	T135_1_681	09:05:00	09:05:00	2	F105
2026-05-19 14:13:19.872748	T135_1_683	17:00:00	17:00:00	1	F147
2026-05-19 14:13:19.872748	T135_1_683	17:05:00	17:05:00	2	F105
2026-05-19 14:13:19.872748	T135_1_685	19:00:00	19:00:00	1	F147
2026-05-19 14:13:19.872748	T135_1_685	19:05:00	19:05:00	2	F105
2026-05-19 14:13:19.872748	T136_0_686	07:00:00	07:00:00	1	F6
2026-05-19 14:13:19.872748	T136_0_686	07:10:00	07:10:00	2	F2
2026-05-19 14:13:19.872748	T136_0_686	08:00:00	08:00:00	3	F200
2026-05-19 14:13:19.872748	T136_1_687	07:00:00	07:00:00	1	F200
2026-05-19 14:13:19.872748	T136_1_687	07:50:00	07:50:00	2	F2
2026-05-19 14:13:19.872748	T136_1_687	08:00:00	08:00:00	3	F6
2026-05-19 14:13:19.872748	T138_0_696	05:00:00	05:00:00	1	F35
2026-05-19 14:13:19.872748	T138_0_696	05:05:00	05:05:00	2	F16
2026-05-19 14:13:19.872748	T138_0_698	09:00:00	09:00:00	1	F35
2026-05-19 14:13:19.872748	T138_0_698	09:05:00	09:05:00	2	F16
2026-05-19 14:13:19.872748	T138_0_700	17:00:00	17:00:00	1	F35
2026-05-19 14:13:19.872748	T138_0_700	17:05:00	17:05:00	2	F16
2026-05-19 14:13:19.872748	T138_0_702	19:00:00	19:00:00	1	F35
2026-05-19 14:13:19.872748	T138_0_702	19:05:00	19:05:00	2	F16
2026-05-19 14:13:19.872748	T138_1_697	05:00:00	05:00:00	1	F16
2026-05-19 14:13:19.872748	T138_1_697	05:05:00	05:05:00	2	F35
2026-05-19 14:13:19.872748	T138_1_699	09:00:00	09:00:00	1	F16
2026-05-19 14:13:19.872748	T138_1_699	09:05:00	09:05:00	2	F35
2026-05-19 14:13:19.872748	T138_1_701	17:00:00	17:00:00	1	F16
2026-05-19 14:13:19.872748	T138_1_701	17:05:00	17:05:00	2	F35
2026-05-19 14:13:19.872748	T138_1_703	19:00:00	19:00:00	1	F16
2026-05-19 14:13:19.872748	T138_1_703	19:05:00	19:05:00	2	F35
2026-05-19 14:13:19.872748	T140_0_720	05:00:00	05:00:00	1	F55
2026-05-19 14:13:19.872748	T140_0_720	05:05:00	05:05:00	2	F75
2026-05-19 14:13:19.872748	T140_0_712	05:00:00	05:00:00	1	F55
2026-05-19 14:13:19.872748	T140_0_712	05:05:00	05:05:00	2	F75
2026-05-19 14:13:19.872748	T140_0_714	09:00:00	09:00:00	1	F55
2026-05-19 14:13:19.872748	T140_0_714	09:05:00	09:05:00	2	F75
2026-05-19 14:13:19.872748	T140_0_722	09:00:00	09:00:00	1	F55
2026-05-19 14:13:19.872748	T140_0_722	09:05:00	09:05:00	2	F75
2026-05-19 14:13:19.872748	T140_0_716	17:00:00	17:00:00	1	F55
2026-05-19 14:13:19.872748	T140_0_716	17:05:00	17:05:00	2	F75
2026-05-19 14:13:19.872748	T140_0_724	17:00:00	17:00:00	1	F55
2026-05-19 14:13:19.872748	T140_0_724	17:05:00	17:05:00	2	F75
2026-05-19 14:13:19.872748	T140_0_726	19:00:00	19:00:00	1	F55
2026-05-19 14:13:19.872748	T140_0_726	19:05:00	19:05:00	2	F75
2026-05-19 14:13:19.872748	T140_0_718	19:00:00	19:00:00	1	F55
2026-05-19 14:13:19.872748	T140_0_718	19:05:00	19:05:00	2	F75
2026-05-19 14:13:19.872748	T140_1_721	05:00:00	05:00:00	1	F75
2026-05-19 14:13:19.872748	T140_1_721	05:05:00	05:05:00	2	F55
2026-05-19 14:13:19.872748	T140_1_713	05:00:00	05:00:00	1	F75
2026-05-19 14:13:19.872748	T140_1_713	05:05:00	05:05:00	2	F55
2026-05-19 14:13:19.872748	T140_1_723	09:00:00	09:00:00	1	F75
2026-05-19 14:13:19.872748	T140_1_723	09:05:00	09:05:00	2	F55
2026-05-19 14:13:19.872748	T140_1_715	09:00:00	09:00:00	1	F75
2026-05-19 14:13:19.872748	T140_1_715	09:05:00	09:05:00	2	F55
2026-05-19 14:13:19.872748	T140_1_717	17:00:00	17:00:00	1	F75
2026-05-19 14:13:19.872748	T140_1_717	17:05:00	17:05:00	2	F55
2026-05-19 14:13:19.872748	T140_1_725	17:00:00	17:00:00	1	F75
2026-05-19 14:13:19.872748	T140_1_725	17:05:00	17:05:00	2	F55
2026-05-19 14:13:19.872748	T140_1_727	19:00:00	19:00:00	1	F75
2026-05-19 14:13:19.872748	T140_1_727	19:05:00	19:05:00	2	F55
2026-05-19 14:13:19.872748	T140_1_719	19:00:00	19:00:00	1	F75
2026-05-19 14:13:19.872748	T140_1_719	19:05:00	19:05:00	2	F55
2026-05-19 14:13:19.872748	T142_0_769	05:00:00	05:00:00	1	F149
2026-05-19 14:13:19.872748	T142_0_769	05:05:00	05:05:00	2	F151
2026-05-19 14:13:19.872748	T142_0_771	09:00:00	09:00:00	1	F149
2026-05-19 14:13:19.872748	T142_0_771	09:05:00	09:05:00	2	F151
2026-05-19 14:13:19.872748	T142_0_773	17:00:00	17:00:00	1	F149
2026-05-19 14:13:19.872748	T142_0_773	17:05:00	17:05:00	2	F151
2026-05-19 14:13:19.872748	T142_0_775	19:00:00	19:00:00	1	F149
2026-05-19 14:13:19.872748	T142_0_775	19:05:00	19:05:00	2	F151
2026-05-19 14:13:19.872748	T142_1_770	05:00:00	05:00:00	1	F151
2026-05-19 14:13:19.872748	T142_1_770	05:05:00	05:05:00	2	F149
2026-05-19 14:13:19.872748	T142_1_772	09:00:00	09:00:00	1	F151
2026-05-19 14:13:19.872748	T142_1_772	09:05:00	09:05:00	2	F149
2026-05-19 14:13:19.872748	T142_1_774	17:00:00	17:00:00	1	F151
2026-05-19 14:13:19.872748	T142_1_774	17:05:00	17:05:00	2	F149
2026-05-19 14:13:19.872748	T142_1_776	19:00:00	19:00:00	1	F151
2026-05-19 14:13:19.872748	T142_1_776	19:05:00	19:05:00	2	F149
2026-05-19 14:13:19.872748	T144_0_760	06:00:00	06:00:00	1	F101
2026-05-19 14:13:19.872748	T144_0_760	08:00:00	08:00:00	2	F139
2026-05-19 14:13:19.872748	T144_0_760	08:30:00	08:30:00	3	F4
2026-05-19 14:13:19.872748	T148_0_801	06:00:00	06:00:00	1	F60
2026-05-19 14:13:19.872748	T148_0_801	06:15:00	06:15:00	2	F73
2026-05-19 14:13:19.872748	T148_0_801	06:17:00	06:17:00	3	F74
2026-05-19 14:13:19.872748	T148_0_801	06:27:00	06:27:00	4	F77
2026-05-19 14:13:19.872748	T148_0_801	06:37:00	06:37:00	5	F89
2026-05-19 14:13:19.872748	T148_0_801	06:52:00	06:52:00	6	F107
2026-05-19 14:13:19.872748	T149_0_802	06:00:00	06:00:00	1	F129
2026-05-19 14:13:19.872748	T149_0_802	06:03:00	06:03:00	2	F24
2026-05-19 14:13:19.872748	T149_1_803	06:00:00	06:00:00	1	F24
2026-05-19 14:13:19.872748	T149_1_803	06:03:00	06:03:00	2	F129
2026-05-19 14:13:19.872748	T154_0_833	07:00:00	07:00:00	1	F6
2026-05-19 14:13:19.872748	T154_0_833	07:10:00	07:10:00	2	F106
2026-05-19 14:13:19.872748	T155_0_835	06:30:00	06:30:00	1	F42
2026-05-19 14:13:19.872748	T155_0_835	07:15:00	07:15:00	2	F1
2026-05-19 14:13:19.872748	T155_0_835	07:30:00	07:30:00	3	F6
2026-05-19 14:13:19.872748	T156_0_836	07:30:00	07:30:00	1	F4
2026-05-19 14:13:19.872748	T156_0_836	08:20:00	08:20:00	2	F57
2026-05-19 14:13:19.872748	T156_0_836	09:20:00	09:20:00	3	F18
2026-05-19 14:13:19.872748	T156_0_836	09:30:00	09:30:00	4	F92
2026-05-19 14:13:19.872748	T156_0_836	09:35:00	09:35:00	5	F101
2026-05-19 14:13:19.872748	T156_0_836	09:40:00	09:40:00	6	F10
2026-05-19 14:13:19.872748	T156_0_836	09:50:00	09:50:00	7	F6
2026-05-19 14:13:19.872748	T156_0_836	10:00:00	10:00:00	8	F1
2026-05-19 14:13:19.872748	T157_0_837	07:30:00	07:30:00	1	F156
2026-05-19 14:13:19.872748	T157_0_837	08:20:00	08:20:00	2	F57
2026-05-19 14:13:19.872748	T157_0_837	09:20:00	09:20:00	3	F18
2026-05-19 14:13:19.872748	T157_0_837	09:30:00	09:30:00	4	F92
2026-05-19 14:13:19.872748	T157_0_837	09:35:00	09:35:00	5	F101
2026-05-19 14:13:19.872748	T157_0_837	09:40:00	09:40:00	6	F10
2026-05-19 14:13:19.872748	T157_0_837	09:50:00	09:50:00	7	F6
2026-05-19 14:13:19.872748	T157_0_837	10:00:00	10:00:00	8	F1
2026-05-19 14:13:19.872748	T158_0_838	07:00:00	07:00:00	1	F88
2026-05-19 14:13:19.872748	T158_0_838	07:30:00	07:30:00	2	F157
2026-05-19 14:13:19.872748	T158_1_839	07:00:00	07:00:00	1	F157
2026-05-19 14:13:19.872748	T158_1_839	07:30:00	07:30:00	2	F88
2026-05-19 14:13:19.872748	T159_0_922	17:30:00	17:30:00	1	F7
2026-05-19 14:13:19.872748	T159_0_922	17:55:00	17:55:00	2	F15
2026-05-19 14:13:19.872748	T159_1_921	06:30:00	06:30:00	1	F15
2026-05-19 14:13:19.872748	T159_1_921	06:55:00	06:55:00	2	F7
2026-05-19 14:13:19.872748	T160_0_924	17:30:00	17:30:00	1	F7
2026-05-19 14:13:19.872748	T160_0_924	17:55:00	17:55:00	2	F14
2026-05-19 14:13:19.872748	T160_1_923	06:30:00	06:30:00	1	F14
2026-05-19 14:13:19.872748	T160_1_923	06:55:00	06:55:00	2	F7
2026-05-19 14:13:19.872748	T161_0_926	17:30:00	17:30:00	1	F7
2026-05-19 14:13:19.872748	T161_0_926	18:05:00	18:05:00	2	F69
2026-05-19 14:13:19.872748	T161_1_925	06:30:00	06:30:00	1	F69
2026-05-19 14:13:19.872748	T161_1_925	07:05:00	07:05:00	2	F7
2026-05-19 14:13:19.872748	T162_0_860	06:00:00	06:00:00	1	F64
2026-05-19 14:13:19.872748	T162_0_860	06:05:00	06:05:00	2	F85
2026-05-19 14:13:19.872748	T162_0_860	06:15:00	06:15:00	3	F10
2026-05-19 14:13:19.872748	T162_0_862	11:00:00	11:00:00	1	F64
2026-05-19 14:13:19.872748	T162_0_862	11:05:00	11:05:00	2	F85
2026-05-19 14:13:19.872748	T162_0_862	11:15:00	11:15:00	3	F10
2026-05-19 14:13:19.872748	T162_0_864	15:30:00	15:30:00	1	F64
2026-05-19 14:13:19.872748	T162_0_864	15:35:00	15:35:00	2	F85
2026-05-19 14:13:19.872748	T162_0_864	15:45:00	15:45:00	3	F10
2026-05-19 14:13:19.872748	T162_1_861	06:00:00	06:00:00	1	F10
2026-05-19 14:13:19.872748	T162_1_861	06:10:00	06:10:00	2	F85
2026-05-19 14:13:19.872748	T162_1_861	06:15:00	06:15:00	3	F64
2026-05-19 14:13:19.872748	T162_1_863	11:00:00	11:00:00	1	F10
2026-05-19 14:13:19.872748	T162_1_863	11:10:00	11:10:00	2	F85
2026-05-19 14:13:19.872748	T162_1_863	11:15:00	11:15:00	3	F64
2026-05-19 14:13:19.872748	T162_1_865	15:30:00	15:30:00	1	F10
2026-05-19 14:13:19.872748	T162_1_865	15:40:00	15:40:00	2	F85
2026-05-19 14:13:19.872748	T162_1_865	15:45:00	15:45:00	3	F64
2026-05-19 14:13:19.872748	T163_0_866	06:00:00	06:00:00	1	F64
2026-05-19 14:13:19.872748	T163_0_866	06:05:00	06:05:00	2	F84
2026-05-19 14:13:19.872748	T163_0_868	11:00:00	11:00:00	1	F64
2026-05-19 14:13:19.872748	T163_0_868	11:05:00	11:05:00	2	F84
2026-05-19 14:13:19.872748	T163_0_870	15:30:00	15:30:00	1	F64
2026-05-19 14:13:19.872748	T163_0_870	15:35:00	15:35:00	2	F84
2026-05-19 14:13:19.872748	T163_1_867	06:00:00	06:00:00	1	F84
2026-05-19 14:13:19.872748	T163_1_867	06:05:00	06:05:00	2	F64
2026-05-19 14:13:19.872748	T163_1_869	11:00:00	11:00:00	1	F84
2026-05-19 14:13:19.872748	T163_1_869	11:05:00	11:05:00	2	F64
2026-05-19 14:13:19.872748	T163_1_871	15:30:00	15:30:00	1	F84
2026-05-19 14:13:19.872748	T163_1_871	15:35:00	15:35:00	2	F64
2026-05-19 14:13:19.872748	T164_0_872	06:00:00	06:00:00	1	F84
2026-05-19 14:13:19.872748	T164_0_872	06:15:00	06:15:00	2	F64
2026-05-19 14:13:19.872748	T164_0_872	06:25:00	06:25:00	3	F85
2026-05-19 14:13:19.872748	T164_0_872	06:35:00	06:35:00	4	F10
2026-05-19 14:13:19.872748	T164_0_874	09:00:00	09:00:00	1	F84
2026-05-19 14:13:19.872748	T164_0_874	09:15:00	09:15:00	2	F64
2026-05-19 14:13:19.872748	T164_0_874	09:25:00	09:25:00	3	F85
2026-05-19 14:13:19.872748	T164_0_874	09:35:00	09:35:00	4	F10
2026-05-19 14:13:19.872748	T164_0_876	13:00:00	13:00:00	1	F84
2026-05-19 14:13:19.872748	T164_0_876	13:15:00	13:15:00	2	F64
2026-05-19 14:13:19.872748	T164_0_876	13:25:00	13:25:00	3	F85
2026-05-19 14:13:19.872748	T164_0_876	13:35:00	13:35:00	4	F10
2026-05-19 14:13:19.872748	T164_0_878	19:00:00	19:00:00	1	F84
2026-05-19 14:13:19.872748	T164_0_878	19:15:00	19:15:00	2	F64
2026-05-19 14:13:19.872748	T164_0_878	19:25:00	19:25:00	3	F85
2026-05-19 14:13:19.872748	T164_0_878	19:35:00	19:35:00	4	F10
2026-05-19 14:13:19.872748	T164_1_873	06:00:00	06:00:00	1	F10
2026-05-19 14:13:19.872748	T164_1_873	06:10:00	06:10:00	2	F85
2026-05-19 14:13:19.872748	T164_1_873	06:20:00	06:20:00	3	F64
2026-05-19 14:13:19.872748	T164_1_873	06:35:00	06:35:00	4	F84
2026-05-19 14:13:19.872748	T164_1_875	09:00:00	09:00:00	1	F10
2026-05-19 14:13:19.872748	T164_1_875	09:10:00	09:10:00	2	F85
2026-05-19 14:13:19.872748	T164_1_875	09:20:00	09:20:00	3	F64
2026-05-19 14:13:19.872748	T164_1_875	09:35:00	09:35:00	4	F84
2026-05-19 14:13:19.872748	T164_1_877	13:00:00	13:00:00	1	F10
2026-05-19 14:13:19.872748	T164_1_877	13:10:00	13:10:00	2	F85
2026-05-19 14:13:19.872748	T164_1_877	13:20:00	13:20:00	3	F64
2026-05-19 14:13:19.872748	T164_1_877	13:35:00	13:35:00	4	F84
2026-05-19 14:13:19.872748	T164_1_879	19:00:00	19:00:00	1	F10
2026-05-19 14:13:19.872748	T164_1_879	19:10:00	19:10:00	2	F85
2026-05-19 14:13:19.872748	T164_1_879	19:20:00	19:20:00	3	F64
2026-05-19 14:13:19.872748	T164_1_879	19:35:00	19:35:00	4	F84
2026-05-19 14:13:19.872748	T165_0_880	06:00:00	06:00:00	1	F78
2026-05-19 14:13:19.872748	T165_0_880	06:05:00	06:05:00	2	F84
2026-05-19 14:13:19.872748	T165_1_881	06:00:00	06:00:00	1	F84
2026-05-19 14:13:19.872748	T165_1_881	06:05:00	06:05:00	2	F78
2026-05-19 14:13:19.872748	T166_0_882	06:00:00	06:00:00	1	F129
2026-05-19 14:13:19.872748	T166_0_882	06:05:00	06:05:00	2	F24
2026-05-19 14:13:19.872748	T166_0_882	06:15:00	06:15:00	3	F90
2026-05-19 14:13:19.872748	T166_0_882	06:20:00	06:20:00	4	F78
2026-05-19 14:13:19.872748	T166_0_882	06:25:00	06:25:00	5	F64
2026-05-19 14:13:19.872748	T166_0_882	06:30:00	06:30:00	6	F85
2026-05-19 14:13:19.872748	T166_0_882	06:35:00	06:35:00	7	F10
2026-05-19 14:13:19.872748	T166_0_884	09:00:00	09:00:00	1	F129
2026-05-19 14:13:19.872748	T166_0_884	09:05:00	09:05:00	2	F24
2026-05-19 14:13:19.872748	T166_0_884	09:15:00	09:15:00	3	F90
2026-05-19 14:13:19.872748	T166_0_884	09:20:00	09:20:00	4	F78
2026-05-19 14:13:19.872748	T166_0_884	09:25:00	09:25:00	5	F64
2026-05-19 14:13:19.872748	T166_0_884	09:30:00	09:30:00	6	F85
2026-05-19 14:13:19.872748	T166_0_884	09:35:00	09:35:00	7	F10
2026-05-19 14:13:19.872748	T166_0_886	13:00:00	13:00:00	1	F129
2026-05-19 14:13:19.872748	T166_0_886	13:05:00	13:05:00	2	F24
2026-05-19 14:13:19.872748	T166_0_886	13:15:00	13:15:00	3	F90
2026-05-19 14:13:19.872748	T166_0_886	13:20:00	13:20:00	4	F78
2026-05-19 14:13:19.872748	T166_0_886	13:25:00	13:25:00	5	F64
2026-05-19 14:13:19.872748	T166_0_886	13:30:00	13:30:00	6	F85
2026-05-19 14:13:19.872748	T166_0_886	13:35:00	13:35:00	7	F10
2026-05-19 14:13:19.872748	T166_0_888	19:00:00	19:00:00	1	F129
2026-05-19 14:13:19.872748	T166_0_888	19:05:00	19:05:00	2	F24
2026-05-19 14:13:19.872748	T166_0_888	19:15:00	19:15:00	3	F90
2026-05-19 14:13:19.872748	T166_0_888	19:20:00	19:20:00	4	F78
2026-05-19 14:13:19.872748	T166_0_888	19:25:00	19:25:00	5	F64
2026-05-19 14:13:19.872748	T166_0_888	19:30:00	19:30:00	6	F85
2026-05-19 14:13:19.872748	T166_0_888	19:35:00	19:35:00	7	F10
2026-05-19 14:13:19.872748	T166_1_883	06:00:00	06:00:00	1	F10
2026-05-19 14:13:19.872748	T166_1_883	06:05:00	06:05:00	2	F85
2026-05-19 14:13:19.872748	T166_1_883	06:10:00	06:10:00	3	F64
2026-05-19 14:13:19.872748	T166_1_883	06:15:00	06:15:00	4	F78
2026-05-19 14:13:19.872748	T166_1_883	06:20:00	06:20:00	5	F90
2026-05-19 14:13:19.872748	T166_1_883	06:30:00	06:30:00	6	F24
2026-05-19 14:13:19.872748	T166_1_883	06:35:00	06:35:00	7	F129
2026-05-19 14:13:19.872748	T166_1_885	09:00:00	09:00:00	1	F10
2026-05-19 14:13:19.872748	T166_1_885	09:05:00	09:05:00	2	F85
2026-05-19 14:13:19.872748	T166_1_885	09:10:00	09:10:00	3	F64
2026-05-19 14:13:19.872748	T166_1_885	09:15:00	09:15:00	4	F78
2026-05-19 14:13:19.872748	T166_1_885	09:20:00	09:20:00	5	F90
2026-05-19 14:13:19.872748	T166_1_885	09:30:00	09:30:00	6	F24
2026-05-19 14:13:19.872748	T166_1_885	09:35:00	09:35:00	7	F129
2026-05-19 14:13:19.872748	T166_1_887	13:00:00	13:00:00	1	F10
2026-05-19 14:13:19.872748	T166_1_887	13:05:00	13:05:00	2	F85
2026-05-19 14:13:19.872748	T166_1_887	13:10:00	13:10:00	3	F64
2026-05-19 14:13:19.872748	T166_1_887	13:15:00	13:15:00	4	F78
2026-05-19 14:13:19.872748	T166_1_887	13:20:00	13:20:00	5	F90
2026-05-19 14:13:19.872748	T166_1_887	13:30:00	13:30:00	6	F24
2026-05-19 14:13:19.872748	T166_1_887	13:35:00	13:35:00	7	F129
2026-05-19 14:13:19.872748	T166_1_889	19:00:00	19:00:00	1	F10
2026-05-19 14:13:19.872748	T166_1_889	19:05:00	19:05:00	2	F85
2026-05-19 14:13:19.872748	T166_1_889	19:10:00	19:10:00	3	F64
2026-05-19 14:13:19.872748	T166_1_889	19:15:00	19:15:00	4	F78
2026-05-19 14:13:19.872748	T166_1_889	19:20:00	19:20:00	5	F90
2026-05-19 14:13:19.872748	T166_1_889	19:30:00	19:30:00	6	F24
2026-05-19 14:13:19.872748	T166_1_889	19:35:00	19:35:00	7	F129
2026-05-19 14:13:19.872748	T168_0_894	07:00:00	07:00:00	1	F81
2026-05-19 14:13:19.872748	T168_0_894	07:20:00	07:20:00	2	F107
2026-05-19 14:13:19.872748	T168_0_896	10:30:00	10:30:00	1	F81
2026-05-19 14:13:19.872748	T168_0_896	10:50:00	10:50:00	2	F107
2026-05-19 14:13:19.872748	T168_1_895	07:00:00	07:00:00	1	F107
2026-05-19 14:13:19.872748	T168_1_895	07:20:00	07:20:00	2	F81
2026-05-19 14:13:19.872748	T168_1_897	10:30:00	10:30:00	1	F107
2026-05-19 14:13:19.872748	T168_1_897	10:50:00	10:50:00	2	F81
2026-05-19 14:13:19.872748	T170_0_906	11:00:00	11:00:00	1	F54
2026-05-19 14:13:19.872748	T170_0_906	11:30:00	11:30:00	2	F130
2026-05-19 14:13:19.872748	T179_0_898	06:30:00	06:30:00	1	F23
2026-05-19 14:13:19.872748	T179_0_898	06:35:00	06:35:00	2	F21
2026-05-19 14:13:19.872748	T179_0_898	06:45:00	06:45:00	3	F112
2026-05-19 14:13:19.872748	T179_0_898	06:50:00	06:50:00	4	F22
2026-05-19 14:13:19.872748	T179_1_899	06:30:00	06:30:00	1	F22
2026-05-19 14:13:19.872748	T179_1_899	06:35:00	06:35:00	2	F112
2026-05-19 14:13:19.872748	T179_1_899	06:45:00	06:45:00	3	F21
2026-05-19 14:13:19.872748	T179_1_899	06:50:00	06:50:00	4	F23
2026-05-19 14:13:19.872748	T180_0_900	06:30:00	06:30:00	1	F51
2026-05-19 14:13:19.872748	T180_0_900	06:35:00	06:35:00	2	F41
2026-05-19 14:13:19.872748	T180_0_901	12:30:00	12:30:00	1	F51
2026-05-19 14:13:19.872748	T180_0_901	12:35:00	12:35:00	2	F41
2026-05-19 14:13:19.872748	T180_0_902	14:30:00	14:30:00	1	F51
2026-05-19 14:13:19.872748	T180_0_902	14:35:00	14:35:00	2	F41
2026-05-19 14:13:19.872748	T180_1_903	06:30:00	06:30:00	1	F41
2026-05-19 14:13:19.872748	T180_1_903	06:35:00	06:35:00	2	F51
2026-05-19 14:13:19.872748	T180_1_904	12:30:00	12:30:00	1	F41
2026-05-19 14:13:19.872748	T180_1_904	12:35:00	12:35:00	2	F51
2026-05-19 14:13:19.872748	T180_1_905	14:30:00	14:30:00	1	F41
2026-05-19 14:13:19.872748	T180_1_905	14:35:00	14:35:00	2	F51
2026-05-19 14:13:19.872748	T181_0_907	06:00:00	06:00:00	1	F79
2026-05-19 14:13:19.872748	T181_0_907	06:08:00	06:08:00	2	F222
2026-05-19 14:13:19.872748	T181_0_909	10:00:00	10:00:00	1	F79
2026-05-19 14:13:19.872748	T181_0_909	10:08:00	10:08:00	2	F222
2026-05-19 14:13:19.872748	T181_0_913	14:00:00	14:00:00	1	F79
2026-05-19 14:13:19.872748	T181_0_913	14:08:00	14:08:00	2	F222
2026-05-19 14:13:19.872748	T181_0_915	16:00:00	16:00:00	1	F79
2026-05-19 14:13:19.872748	T181_0_915	16:08:00	16:08:00	2	F222
2026-05-19 14:13:19.872748	T181_1_908	06:00:00	06:00:00	1	F222
2026-05-19 14:13:19.872748	T181_1_908	06:08:00	06:08:00	2	F79
2026-05-19 14:13:19.872748	T181_1_910	10:00:00	10:00:00	1	F222
2026-05-19 14:13:19.872748	T181_1_910	10:08:00	10:08:00	2	F79
2026-05-19 14:13:19.872748	T181_1_914	14:00:00	14:00:00	1	F222
2026-05-19 14:13:19.872748	T181_1_914	14:08:00	14:08:00	2	F79
2026-05-19 14:13:19.872748	T181_1_916	16:00:00	16:00:00	1	F222
2026-05-19 14:13:19.872748	T181_1_916	16:08:00	16:08:00	2	F79
\.


--
-- Data for Name: stops_gtfs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.stops_gtfs (generated_at, stop_id, stop_name, stop_lat, stop_lon) FROM stdin;
2026-05-19 14:13:19.872748	F1	Ebute Ero/Elegbata Jetty	6.462741	3.3824812
2026-05-19 14:13:19.872748	F2	Five Cowries/Falomo (Ikoyi)	6.442095174	3.427179994
2026-05-19 14:13:19.872748	F3	Ikorodu/Ipakodo Ferry Terminal	6.601832	3.4862304
2026-05-19 14:13:19.872748	F4	Port Novo (Benin Republic)	6.466004874097848	2.6233855442023355
2026-05-19 14:13:19.872748	F5	Flour Mills (Apapa)	6.4477052	3.3749219
2026-05-19 14:13:19.872748	F6	Marina/CMS	6.4492081354225945	3.389713112398539
2026-05-19 14:13:19.872748	F7	Addax/Sandfill/Maroko (Victoria Island)	6.436702621424786	3.4419826471853696
2026-05-19 14:13:19.872748	F8	Badore Jetty (Tarzan)	6.5151518	3.6054649
2026-05-19 14:13:19.872748	F9	Ebute Ojo/Sifax Ferry Terminal	6.453045	3.2055781
2026-05-19 14:13:19.872748	F10	Liverpool (Apapa)	6.4390793	3.3592365
2026-05-19 14:13:19.872748	F12	Alluvia Marine/Afisco (Lekki Phase 1)	6.4475959	3.4590768
2026-05-19 14:13:19.872748	F13	Jegba Marina Badagry/Commando Jetty	6.416007847	2.876014607
2026-05-19 14:13:19.872748	F14	Offin, Ikorodu	6.5393273	3.5010197
2026-05-19 14:13:19.872748	F15	Ibeshe/Thesaurus Ferry Terminal	6.5523891	3.4728735
2026-05-19 14:13:19.872748	F16	Number 3 (Ajegunle) Waterside	6.450393857	3.351162411
2026-05-19 14:13:19.872748	F17	Abomiti-Nla Epe	6.519404103752237	4.09519204016695
2026-05-19 14:13:19.872748	F18	Abule Osun	6.437043497	3.23667811
2026-05-19 14:13:19.872748	F19	Agaja	6.403919063	3.164768668
2026-05-19 14:13:19.872748	F20	Agboyi 3	6.5824155	3.4081684
2026-05-19 14:13:19.872748	F21	Agboyi 2	6.5802865	3.4084039
2026-05-19 14:13:19.872748	F22	Oko Agbon	6.5798309	3.4108125
2026-05-19 14:13:19.872748	F23	Agboyi Ketu	6.5825306	3.4075406
2026-05-19 14:13:19.872748	F24	Agojedo/Agbejedo	6.417626165505482	3.3588530258308253
2026-05-19 14:13:19.872748	F27	Allens Unit/Alex (Apapa)	6.4346659	3.3700913
2026-05-19 14:13:19.872748	F30	Baba Shino	6.424669926	3.257495156
2026-05-19 14:13:19.872748	F31	Baiyeku	6.536139	3.553069
2026-05-19 14:13:19.872748	F35	Boundary (Apapa)/Number 3 (Apapa) Waterside	6.450410928	3.351580945
2026-05-19 14:13:19.872748	F36	Capital Oil/FESTAC	6.474484688	3.294149195
2026-05-19 14:13:19.872748	F38	Coconut Landing	6.4379208	3.3358558
2026-05-19 14:13:19.872748	F41	Egan Landing	6.447364946	3.141547596
2026-05-19 14:13:19.872748	F42	Egbin	6.56021613	3.600195878
2026-05-19 14:13:19.872748	F44	Elegushi	6.411355033	3.254269161
2026-05-19 14:13:19.872748	F46	Epe Ayetoro Jetty	6.577579	3.975230
2026-05-19 14:13:19.872748	F51	Etegbin	6.44938129866523	3.1438987931594227
2026-05-19 14:13:19.872748	F54	Fiki Marine (Victoria Island)	6.43922746	3.424595555
2026-05-19 14:13:19.872748	F55	First Gate (Tin Can Island)	6.435334458	3.343388481
2026-05-19 14:13:19.872748	F57	Gbaji Yekeme Jetty	6.419563687	2.86074950
2026-05-19 14:13:19.872748	F58	Gberigbe	6.571305167	3.636099754
2026-05-19 14:13:19.872748	F59	Ibasa	6.424950503	3.255345985
2026-05-19 14:13:19.872748	F60	Ibese	6.407574489	3.261663392
2026-05-19 14:13:19.872748	F62	Ibeshe Palace	6.411298075	3.255760155
2026-05-19 14:13:19.872748	F63	Igando Landing/Isuti	6.552229	3.206473
2026-05-19 14:13:19.872748	F64	Igbo Elejo	6.42421763	3.352115435
2026-05-19 14:13:19.872748	F67	Igbologun/Snake Island	6.427478038731522	3.3345191161320713
2026-05-19 14:13:19.872748	F69	Ijede/Tarzan	6.5632172	3.5890471
2026-05-19 14:13:19.872748	F70	Ijegun Egba	6.427831	3.258691
2026-05-19 14:13:19.872748	F71	Ijon	6.563707	3.20189717
2026-05-19 14:13:19.872748	F73	Ikare palace	6.417633427	3.238141222
2026-05-19 14:13:19.872748	F74	Ikare town landing	6.417336462	3.236747347
2026-05-19 14:13:19.872748	F75	IKO/Temidire	6.436872961	3.344148423
2026-05-19 14:13:19.872748	F77	Ilashe	6.40667	3.2055711
2026-05-19 14:13:19.872748	F78	Ilutuntun	6.422202391	3.349318874
2026-05-19 14:13:19.872748	F79	Imore Waterside	6.430224369	3.280752801
2026-05-19 14:13:19.872748	F80	Irede	6.428563414	3.235353134
2026-05-19 14:13:19.872748	F81	Irewe Ojo	6.424470195400829	3.1529759503605135
2026-05-19 14:13:19.872748	F83	Isashi Landing	6.510683	3.173494
2026-05-19 14:13:19.872748	F84	Isoda	6.426355469	3.347746321
2026-05-19 14:13:19.872748	F85	Itun Agan	6.427667306	3.359240179
2026-05-19 14:13:19.872748	F86	Itomu Jetty	6.500702360667333	3.6287304042043047
2026-05-19 14:13:19.872748	F88	Iya Afin Jetty	6.445606177	2.8608538
2026-05-19 14:13:19.872748	F89	Iyagbe	6.419640776	3.19931338
2026-05-19 14:13:19.872748	F90	Jemuje	6.417815267	3.350526717
2026-05-19 14:13:19.872748	F91	KabaKaba	6.4311226	3.3733927
2026-05-19 14:13:19.872748	F92	Kirikiri	6.437342371	3.310792342
2026-05-19 14:13:19.872748	F93	Koko beach	6.409081268	3.24343704
2026-05-19 14:13:19.872748	F99	Manager	6.429986033	3.370910736
2026-05-19 14:13:19.872748	F100	Mikano	6.407742225	3.216321522
2026-05-19 14:13:19.872748	F101	Mile 2/NIWA	6.4590664	3.3077366
2026-05-19 14:13:19.872748	F102	Mogaji (Ajegunle)	6.446059237	3.349851834
2026-05-19 14:13:19.872748	F104	Number 1A Waterside	6.44263934	3.349289318
2026-05-19 14:13:19.872748	F105	Number 2 (Apapa) Waterside	6.44823066	3.351415
2026-05-19 14:13:19.872748	F106	Ogogoro Village	6.426261846113661	3.3983397610213615
2026-05-19 14:13:19.872748	F107	Ojo market waterside	6.453176022	3.204245481
2026-05-19 14:13:19.872748	F109	Oke Ira Nla (Ajah)	6.4906336	3.5790217
2026-05-19 14:13:19.872748	F112	Agboyi 1	6.579565	3.409751
2026-05-19 14:13:19.872748	F114	Olu landing	6.407796141	3.259976411
2026-05-19 14:13:19.872748	F119	Police	6.411970909	3.252469639
2026-05-19 14:13:19.872748	F120	Power line	6.415655161	3.247618113
2026-05-19 14:13:19.872748	F121	Sagbokoji	6.43277977	3.376968865
2026-05-19 14:13:19.872748	F122	Salt Beach	6.406064982	3.2236361
2026-05-19 14:13:19.872748	F124	Second Badagry	6.441039888	3.348588954
2026-05-19 14:13:19.872748	F125	Second Rainbow Landing	6.425671629	3.262277583
2026-05-19 14:13:19.872748	F129	Itomoro	6.418094084	3.362453877
2026-05-19 14:13:19.872748	F130	Tarkwa Bay	6.4010654	3.3965995
2026-05-19 14:13:19.872748	F135	Uncle Ben	6.40810007	3.215426604
2026-05-19 14:13:19.872748	F139	Pashi	6.444708	2.708001
2026-05-19 14:13:19.872748	F141	Isofin	6.449265067922099	3.1451277430765003
2026-05-19 14:13:19.872748	F142	Itekun (Ogun)	6.514275458385697	3.170501289484946
2026-05-19 14:13:19.872748	F144	Ijon Odo (Ogun)	6.561944	3.195462
2026-05-19 14:13:19.872748	F145	Oto Owu Odo (Ogun)	6.552369	3.198343
2026-05-19 14:13:19.872748	F147	Number 2 (Ajegunle) Waterside/Kumuyi Street(Ajegunle)	6.448440081	3.350893109
2026-05-19 14:13:19.872748	F149	Number 1 (Ajegunle) Waterside	6.4463	3.3500
2026-05-19 14:13:19.872748	F151	Number 1 (Apapa) Waterside	6.4461	3.3505
2026-05-19 14:13:19.872748	F152	Kabiyesi itomu jetty	6.502234	3.626850
2026-05-19 14:13:19.872748	F153	Ipare (Ondo)	6.2907986756471	4.674969608516989
2026-05-19 14:13:19.872748	F154	Iwopin (Ogun)	6.5182992422275134	4.192336731520612
2026-05-19 14:13:19.872748	F155	Eyin Osa	6.567449855315829	3.9753541928079983
2026-05-19 14:13:19.872748	F156	Farasime	6.4308333868929	2.7098418861795324
2026-05-19 14:13:19.872748	F157	Izigi (Ogun)	6.472321493181269	2.862023411768888
2026-05-19 14:13:19.872748	F200	Badore Ferry Terminal	6.5121945	3.6152349
2026-05-19 14:13:19.872748	F220	Alelegbene	6.426392	3.355594
2026-05-19 14:13:19.872748	F222	Imore Community	6.426853	3.280746
\.


--
-- Data for Name: trips_gtfs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.trips_gtfs (generated_at, trip_id, route_id, service_id, trip_headsign, direction_id, shape_id, bikes_allowed) FROM stdin;
2026-05-19 14:13:19.872748	T4_0_465	R4	SVC_1111100	Offin, Ikorodu	0	S4	0
2026-05-19 14:13:19.872748	T4_1_464	R4	SVC_1111100	Five Cowries/Falomo (Ikoyi)	1	S4	0
2026-05-19 14:13:19.872748	T8_0_462	R8	SVC_1111100	Five Cowries/Falomo (Ikoyi)	0	S8	0
2026-05-19 14:13:19.872748	T8_1_463	R8	SVC_1111100	Ikorodu/Ipakodo Ferry Terminal	1	S8	0
2026-05-19 14:13:19.872748	T9_0_470	R9	SVC_1111100	Flour Mills (Apapa)	0	S9	0
2026-05-19 14:13:19.872748	T9_1_471	R9	SVC_1111100	Ikorodu/Ipakodo Ferry Terminal	1	S9	0
2026-05-19 14:13:19.872748	T10_0_466	R10	SVC_1111100	Liverpool (Apapa)	0	S10	0
2026-05-19 14:13:19.872748	T10_1_467	R10	SVC_1111100	Ikorodu/Ipakodo Ferry Terminal	1	S10	0
2026-05-19 14:13:19.872748	T11_0_476	R11	SVC_0000011	Five Cowries/Falomo (Ikoyi)	0	S11	0
2026-05-19 14:13:19.872748	T11_0_474	R11	SVC_1111100	Five Cowries/Falomo (Ikoyi)	0	S11	0
2026-05-19 14:13:19.872748	T11_0_480	R11	SVC_0000011	Five Cowries/Falomo (Ikoyi)	0	S11	0
2026-05-19 14:13:19.872748	T11_0_478	R11	SVC_1111100	Five Cowries/Falomo (Ikoyi)	0	S11	0
2026-05-19 14:13:19.872748	T11_0_479	R11	SVC_1111100	Five Cowries/Falomo (Ikoyi)	0	S11	0
2026-05-19 14:13:19.872748	T11_1_475	R11	SVC_1111100	Ikorodu/Ipakodo Ferry Terminal	1	S11	0
2026-05-19 14:13:19.872748	T11_1_477	R11	SVC_0000011	Ikorodu/Ipakodo Ferry Terminal	1	S11	0
2026-05-19 14:13:19.872748	T11_1_481	R11	SVC_1111100	Ikorodu/Ipakodo Ferry Terminal	1	S11	0
2026-05-19 14:13:19.872748	T12_0_25	R12	SVC_1111111	Manager	0	S12	0
2026-05-19 14:13:19.872748	T12_0_27	R12	SVC_1111111	Manager	0	S12	0
2026-05-19 14:13:19.872748	T12_0_29	R12	SVC_1111111	Manager	0	S12	0
2026-05-19 14:13:19.872748	T12_0_31	R12	SVC_1111111	Manager	0	S12	0
2026-05-19 14:13:19.872748	T12_0_33	R12	SVC_1111111	Manager	0	S12	0
2026-05-19 14:13:19.872748	T12_0_35	R12	SVC_1111111	Manager	0	S12	0
2026-05-19 14:13:19.872748	T12_1_26	R12	SVC_1111111	Allens Unit/Alex (Apapa)	1	S12	0
2026-05-19 14:13:19.872748	T12_1_28	R12	SVC_1111111	Allens Unit/Alex (Apapa)	1	S12	0
2026-05-19 14:13:19.872748	T12_1_30	R12	SVC_1111111	Allens Unit/Alex (Apapa)	1	S12	0
2026-05-19 14:13:19.872748	T12_1_32	R12	SVC_1111111	Allens Unit/Alex (Apapa)	1	S12	0
2026-05-19 14:13:19.872748	T12_1_34	R12	SVC_1111111	Allens Unit/Alex (Apapa)	1	S12	0
2026-05-19 14:13:19.872748	T12_1_36	R12	SVC_1111111	Allens Unit/Alex (Apapa)	1	S12	0
2026-05-19 14:13:19.872748	T13_0_37	R13	SVC_1111111	KabaKaba	0	S13	0
2026-05-19 14:13:19.872748	T13_0_39	R13	SVC_1111111	KabaKaba	0	S13	0
2026-05-19 14:13:19.872748	T13_0_41	R13	SVC_1111111	KabaKaba	0	S13	0
2026-05-19 14:13:19.872748	T13_0_43	R13	SVC_1111111	KabaKaba	0	S13	0
2026-05-19 14:13:19.872748	T13_0_45	R13	SVC_1111111	KabaKaba	0	S13	0
2026-05-19 14:13:19.872748	T13_0_47	R13	SVC_1111111	KabaKaba	0	S13	0
2026-05-19 14:13:19.872748	T13_1_38	R13	SVC_1111111	Allens Unit/Alex (Apapa)	1	S13	0
2026-05-19 14:13:19.872748	T13_1_40	R13	SVC_1111111	Allens Unit/Alex (Apapa)	1	S13	0
2026-05-19 14:13:19.872748	T13_1_42	R13	SVC_1111111	Allens Unit/Alex (Apapa)	1	S13	0
2026-05-19 14:13:19.872748	T13_1_44	R13	SVC_1111111	Allens Unit/Alex (Apapa)	1	S13	0
2026-05-19 14:13:19.872748	T13_1_46	R13	SVC_1111111	Allens Unit/Alex (Apapa)	1	S13	0
2026-05-19 14:13:19.872748	T13_1_48	R13	SVC_1111111	Allens Unit/Alex (Apapa)	1	S13	0
2026-05-19 14:13:19.872748	T14_0_49	R14	SVC_1111111	Sagbokoji	0	S14	0
2026-05-19 14:13:19.872748	T14_0_51	R14	SVC_1111111	Sagbokoji	0	S14	0
2026-05-19 14:13:19.872748	T14_0_53	R14	SVC_1111111	Sagbokoji	0	S14	0
2026-05-19 14:13:19.872748	T14_0_55	R14	SVC_1111111	Sagbokoji	0	S14	0
2026-05-19 14:13:19.872748	T14_0_57	R14	SVC_1111111	Sagbokoji	0	S14	0
2026-05-19 14:13:19.872748	T14_1_50	R14	SVC_1111111	Allens Unit/Alex (Apapa)	1	S14	0
2026-05-19 14:13:19.872748	T14_1_52	R14	SVC_1111111	Allens Unit/Alex (Apapa)	1	S14	0
2026-05-19 14:13:19.872748	T14_1_54	R14	SVC_1111111	Allens Unit/Alex (Apapa)	1	S14	0
2026-05-19 14:13:19.872748	T14_1_56	R14	SVC_1111111	Allens Unit/Alex (Apapa)	1	S14	0
2026-05-19 14:13:19.872748	T14_1_58	R14	SVC_1111111	Allens Unit/Alex (Apapa)	1	S14	0
2026-05-19 14:13:19.872748	T16_0_65	R16	SVC_1111110	Sagbokoji	0	S16	0
2026-05-19 14:13:19.872748	T16_0_67	R16	SVC_1111110	Sagbokoji	0	S16	0
2026-05-19 14:13:19.872748	T16_1_66	R16	SVC_1111110	Liverpool (Apapa)	1	S16	0
2026-05-19 14:13:19.872748	T16_1_68	R16	SVC_1111110	Liverpool (Apapa)	1	S16	0
2026-05-19 14:13:19.872748	T17_0_71	R17	SVC_1111110	Badore Ferry Terminal	0	S17	0
2026-05-19 14:13:19.872748	T17_1_70	R17	SVC_1111110	Liverpool (Apapa)	1	S17	0
2026-05-19 14:13:19.872748	T19_0_77	R19	SVC_1111110	Boundary (Apapa)/Number 3 (Apapa) Waterside	0	S19	0
2026-05-19 14:13:19.872748	T19_1_78	R19	SVC_1111110	Liverpool (Apapa)	1	S19	0
2026-05-19 14:13:19.872748	T24_0_102	R24	SVC_0000011	Tarkwa Bay	0	S24	0
2026-05-19 14:13:19.872748	T24_1_103	R24	SVC_0000011	Liverpool (Apapa)	1	S24	0
2026-05-19 14:13:19.872748	T25_0_104	R25	SVC_1111110	Igbologun/Snake Island	0	S25	0
2026-05-19 14:13:19.872748	T25_0_106	R25	SVC_1111110	Igbologun/Snake Island	0	S25	0
2026-05-19 14:13:19.872748	T25_0_108	R25	SVC_1111110	Igbologun/Snake Island	0	S25	0
2026-05-19 14:13:19.872748	T25_1_105	R25	SVC_1111110	Coconut Landing	1	S25	0
2026-05-19 14:13:19.872748	T25_1_107	R25	SVC_1111110	Coconut Landing	1	S25	0
2026-05-19 14:13:19.872748	T25_1_109	R25	SVC_1111110	Coconut Landing	1	S25	0
2026-05-19 14:13:19.872748	T27_0_116	R27	SVC_1111110	Baba Shino	0	S27	0
2026-05-19 14:13:19.872748	T27_0_118	R27	SVC_1111110	Baba Shino	0	S27	0
2026-05-19 14:13:19.872748	T27_0_120	R27	SVC_1111110	Baba Shino	0	S27	0
2026-05-19 14:13:19.872748	T27_1_117	R27	SVC_1111110	Ijegun Egba	1	S27	0
2026-05-19 14:13:19.872748	T27_1_119	R27	SVC_1111110	Ijegun Egba	1	S27	0
2026-05-19 14:13:19.872748	T27_1_121	R27	SVC_1111110	Ijegun Egba	1	S27	0
2026-05-19 14:13:19.872748	T28_0_122	R28	SVC_1111110	Second Rainbow Landing	0	S28	0
2026-05-19 14:13:19.872748	T28_0_124	R28	SVC_1111110	Second Rainbow Landing	0	S28	0
2026-05-19 14:13:19.872748	T28_0_126	R28	SVC_1111110	Second Rainbow Landing	0	S28	0
2026-05-19 14:13:19.872748	T28_1_123	R28	SVC_1111110	Ijegun Egba	1	S28	0
2026-05-19 14:13:19.872748	T28_1_125	R28	SVC_1111110	Ijegun Egba	1	S28	0
2026-05-19 14:13:19.872748	T28_1_127	R28	SVC_1111110	Ijegun Egba	1	S28	0
2026-05-19 14:13:19.872748	T29_0_128	R29	SVC_1111110	Ibasa	0	S29	0
2026-05-19 14:13:19.872748	T29_0_130	R29	SVC_1111110	Ibasa	0	S29	0
2026-05-19 14:13:19.872748	T29_0_132	R29	SVC_1111110	Ibasa	0	S29	0
2026-05-19 14:13:19.872748	T29_1_129	R29	SVC_1111110	Ijegun Egba	1	S29	0
2026-05-19 14:13:19.872748	T29_1_131	R29	SVC_1111110	Ijegun Egba	1	S29	0
2026-05-19 14:13:19.872748	T29_1_133	R29	SVC_1111110	Ijegun Egba	1	S29	0
2026-05-19 14:13:19.872748	T30_0_134	R30	SVC_1111100	Ibeshe Palace	0	S30	0
2026-05-19 14:13:19.872748	T30_0_136	R30	SVC_0000010	Ibeshe Palace	0	S30	0
2026-05-19 14:13:19.872748	T30_0_138	R30	SVC_0000010	Ibeshe Palace	0	S30	0
2026-05-19 14:13:19.872748	T30_1_135	R30	SVC_1111100	Ijegun Egba	1	S30	0
2026-05-19 14:13:19.872748	T30_1_137	R30	SVC_0000010	Ijegun Egba	1	S30	0
2026-05-19 14:13:19.872748	T30_1_139	R30	SVC_0000010	Ijegun Egba	1	S30	0
2026-05-19 14:13:19.872748	T31_0_140	R31	SVC_1111110	Port Novo (Benin Republic)	0	S31	0
2026-05-19 14:13:19.872748	T33_0_142	R33	SVC_1111110	Irede	0	S33	0
2026-05-19 14:13:19.872748	T33_0_144	R33	SVC_1111110	Irede	0	S33	0
2026-05-19 14:13:19.872748	T33_0_146	R33	SVC_1111110	Irede	0	S33	0
2026-05-19 14:13:19.872748	T33_1_143	R33	SVC_1111110	Abule Osun	1	S33	0
2026-05-19 14:13:19.872748	T33_1_145	R33	SVC_1111110	Abule Osun	1	S33	0
2026-05-19 14:13:19.872748	T33_1_147	R33	SVC_1111110	Abule Osun	1	S33	0
2026-05-19 14:13:19.872748	T34_0_187	R34	SVC_1111100	Five Cowries/Falomo (Ikoyi)	0	S34	0
2026-05-19 14:13:19.872748	T34_0_183	R34	SVC_1111100	Five Cowries/Falomo (Ikoyi)	0	S34	0
2026-05-19 14:13:19.872748	T34_0_191	R34	SVC_0000010	Five Cowries/Falomo (Ikoyi)	0	S34	0
2026-05-19 14:13:19.872748	T36_0_193	R36	SVC_1111100	Liverpool (Apapa)	0	S36	0
2026-05-19 14:13:19.872748	T36_1_196	R36	SVC_1111100	Ibeshe/Thesaurus Ferry Terminal	1	S36	0
2026-05-19 14:13:19.872748	T37_0_197	R37	SVC_1111100	Five Cowries/Falomo (Ikoyi)	0	S37	0
2026-05-19 14:13:19.872748	T37_1_200	R37	SVC_1111100	Offin, Ikorodu	1	S37	0
2026-05-19 14:13:19.872748	T38_0_201	R38	SVC_1111110	Badore Jetty (Tarzan)	0	S38	0
2026-05-19 14:13:19.872748	T38_0_203	R38	SVC_1111110	Badore Jetty (Tarzan)	0	S38	0
2026-05-19 14:13:19.872748	T38_1_204	R38	SVC_1111110	Ijede/Tarzan	1	S38	0
2026-05-19 14:13:19.872748	T38_1_206	R38	SVC_1111110	Ijede/Tarzan	1	S38	0
2026-05-19 14:13:19.872748	T40_0_213	R40	SVC_1111110	Five Cowries/Falomo (Ikoyi)	0	S40	0
2026-05-19 14:13:19.872748	T40_1_216	R40	SVC_1111110	Ijede/Tarzan	1	S40	0
2026-05-19 14:13:19.872748	T41_0_217	R41	SVC_1111110	Baiyeku	0	S41	0
2026-05-19 14:13:19.872748	T41_0_219	R41	SVC_1111110	Baiyeku	0	S41	0
2026-05-19 14:13:19.872748	T41_1_218	R41	SVC_1111110	Oke Ira Nla (Ajah)	1	S41	0
2026-05-19 14:13:19.872748	T41_1_220	R41	SVC_1111110	Oke Ira Nla (Ajah)	1	S41	0
2026-05-19 14:13:19.872748	T43_0_227	R43	SVC_1111110	Ijon Odo (Ogun)	0	S43	0
2026-05-19 14:13:19.872748	T43_0_229	R43	SVC_1111110	Ijon Odo (Ogun)	0	S43	0
2026-05-19 14:13:19.872748	T43_0_231	R43	SVC_1111110	Ijon Odo (Ogun)	0	S43	0
2026-05-19 14:13:19.872748	T43_1_228	R43	SVC_1111110	Ijon	1	S43	0
2026-05-19 14:13:19.872748	T43_1_230	R43	SVC_1111110	Ijon	1	S43	0
2026-05-19 14:13:19.872748	T43_1_232	R43	SVC_1111110	Ijon	1	S43	0
2026-05-19 14:13:19.872748	T44_0_233	R44	SVC_1111100	Oto Owu Odo (Ogun)	0	S44	0
2026-05-19 14:13:19.872748	T44_0_243	R44	SVC_0000010	Oto Owu Odo (Ogun)	0	S44	0
2026-05-19 14:13:19.872748	T44_0_235	R44	SVC_1111100	Oto Owu Odo (Ogun)	0	S44	0
2026-05-19 14:13:19.872748	T44_0_245	R44	SVC_0000010	Oto Owu Odo (Ogun)	0	S44	0
2026-05-19 14:13:19.872748	T44_0_237	R44	SVC_1111100	Oto Owu Odo (Ogun)	0	S44	0
2026-05-19 14:13:19.872748	T44_0_247	R44	SVC_0000010	Oto Owu Odo (Ogun)	0	S44	0
2026-05-19 14:13:19.872748	T44_0_239	R44	SVC_1111100	Oto Owu Odo (Ogun)	0	S44	0
2026-05-19 14:13:19.872748	T44_0_241	R44	SVC_1111100	Oto Owu Odo (Ogun)	0	S44	0
2026-05-19 14:13:19.872748	T44_1_234	R44	SVC_1111100	Igando Landing/Isuti	1	S44	0
2026-05-19 14:13:19.872748	T44_1_244	R44	SVC_0000010	Igando Landing/Isuti	1	S44	0
2026-05-19 14:13:19.872748	T44_1_236	R44	SVC_1111100	Igando Landing/Isuti	1	S44	0
2026-05-19 14:13:19.872748	T44_1_246	R44	SVC_0000010	Igando Landing/Isuti	1	S44	0
2026-05-19 14:13:19.872748	T44_1_238	R44	SVC_1111100	Igando Landing/Isuti	1	S44	0
2026-05-19 14:13:19.872748	T44_1_248	R44	SVC_0000010	Igando Landing/Isuti	1	S44	0
2026-05-19 14:13:19.872748	T44_1_240	R44	SVC_1111100	Igando Landing/Isuti	1	S44	0
2026-05-19 14:13:19.872748	T44_1_242	R44	SVC_1111100	Igando Landing/Isuti	1	S44	0
2026-05-19 14:13:19.872748	T45_0_249	R45	SVC_1111110	Irewe Ojo	0	S45	0
2026-05-19 14:13:19.872748	T45_1_250	R45	SVC_1111110	Ebute Ojo/Sifax Ferry Terminal	1	S45	0
2026-05-19 14:13:19.872748	T46_0_251	R46	SVC_1111110	Ikare town landing	0	S46	0
2026-05-19 14:13:19.872748	T46_1_252	R46	SVC_1111110	Ebute Ojo/Sifax Ferry Terminal	1	S46	0
2026-05-19 14:13:19.872748	T47_0_255	R47	SVC_1111110	Ilashe	0	S47	0
2026-05-19 14:13:19.872748	T47_1_254	R47	SVC_1111110	Ebute Ojo/Sifax Ferry Terminal	1	S47	0
2026-05-19 14:13:19.872748	T48_0_257	R48	SVC_1111100	Agaja	0	S48	0
2026-05-19 14:13:19.872748	T48_0_259	R48	SVC_0000010	Agaja	0	S48	0
2026-05-19 14:13:19.872748	T48_1_258	R48	SVC_1111100	Ebute Ojo/Sifax Ferry Terminal	1	S48	0
2026-05-19 14:13:19.872748	T48_1_260	R48	SVC_0000010	Ebute Ojo/Sifax Ferry Terminal	1	S48	0
2026-05-19 14:13:19.872748	T49_0_265	R49	SVC_0000010	Marina/CMS	0	S49	0
2026-05-19 14:13:19.872748	T49_0_261	R49	SVC_1111100	Marina/CMS	0	S49	0
2026-05-19 14:13:19.872748	T49_1_266	R49	SVC_0000010	Ebute Ojo/Sifax Ferry Terminal	1	S49	0
2026-05-19 14:13:19.872748	T49_1_264	R49	SVC_1111100	Ebute Ojo/Sifax Ferry Terminal	1	S49	0
2026-05-19 14:13:19.872748	T50_0_267	R50	SVC_1111110	Agboyi 3	0	S50	0
2026-05-19 14:13:19.872748	T50_1_268	R50	SVC_1111110	Agboyi Ketu	1	S50	0
2026-05-19 14:13:19.872748	T53_0_277	R53	SVC_1111110	Isofin	0	S53	0
2026-05-19 14:13:19.872748	T53_0_279	R53	SVC_1111110	Isofin	0	S53	0
2026-05-19 14:13:19.872748	T53_0_281	R53	SVC_1111110	Isofin	0	S53	0
2026-05-19 14:13:19.872748	T53_1_278	R53	SVC_1111110	Etegbin	1	S53	0
2026-05-19 14:13:19.872748	T53_1_280	R53	SVC_1111110	Etegbin	1	S53	0
2026-05-19 14:13:19.872748	T53_1_282	R53	SVC_1111110	Etegbin	1	S53	0
2026-05-19 14:13:19.872748	T54_0_283	R54	SVC_1111100	Itekun (Ogun)	0	S54	0
2026-05-19 14:13:19.872748	T54_0_291	R54	SVC_0000010	Itekun (Ogun)	0	S54	0
2026-05-19 14:13:19.872748	T54_0_285	R54	SVC_1111100	Itekun (Ogun)	0	S54	0
2026-05-19 14:13:19.872748	T54_0_293	R54	SVC_0000010	Itekun (Ogun)	0	S54	0
2026-05-19 14:13:19.872748	T54_0_287	R54	SVC_1111100	Itekun (Ogun)	0	S54	0
2026-05-19 14:13:19.872748	T54_0_289	R54	SVC_1111100	Itekun (Ogun)	0	S54	0
2026-05-19 14:13:19.872748	T54_1_292	R54	SVC_0000010	Isashi Landing	1	S54	0
2026-05-19 14:13:19.872748	T54_1_284	R54	SVC_1111100	Isashi Landing	1	S54	0
2026-05-19 14:13:19.872748	T54_1_294	R54	SVC_0000010	Isashi Landing	1	S54	0
2026-05-19 14:13:19.872748	T54_1_286	R54	SVC_1111100	Isashi Landing	1	S54	0
2026-05-19 14:13:19.872748	T54_1_288	R54	SVC_1111100	Isashi Landing	1	S54	0
2026-05-19 14:13:19.872748	T54_1_290	R54	SVC_1111100	Isashi Landing	1	S54	0
2026-05-19 14:13:19.872748	T63_0_323	R63	SVC_1111110	Itun Agan	0	S63	0
2026-05-19 14:13:19.872748	T63_0_325	R63	SVC_1111110	Itun Agan	0	S63	0
2026-05-19 14:13:19.872748	T63_0_327	R63	SVC_1111110	Itun Agan	0	S63	0
2026-05-19 14:13:19.872748	T63_0_329	R63	SVC_1111110	Itun Agan	0	S63	0
2026-05-19 14:13:19.872748	T63_0_331	R63	SVC_1111110	Itun Agan	0	S63	0
2026-05-19 14:13:19.872748	T63_1_324	R63	SVC_1111110	Liverpool (Apapa)	1	S63	0
2026-05-19 14:13:19.872748	T63_1_326	R63	SVC_1111110	Liverpool (Apapa)	1	S63	0
2026-05-19 14:13:19.872748	T63_1_328	R63	SVC_1111110	Liverpool (Apapa)	1	S63	0
2026-05-19 14:13:19.872748	T63_1_330	R63	SVC_1111110	Liverpool (Apapa)	1	S63	0
2026-05-19 14:13:19.872748	T63_1_332	R63	SVC_1111110	Liverpool (Apapa)	1	S63	0
2026-05-19 14:13:19.872748	T64_0_333	R64	SVC_1111110	Isoda	0	S64	0
2026-05-19 14:13:19.872748	T64_0_335	R64	SVC_1111110	Isoda	0	S64	0
2026-05-19 14:13:19.872748	T64_0_337	R64	SVC_1111110	Isoda	0	S64	0
2026-05-19 14:13:19.872748	T64_1_334	R64	SVC_1111110	Liverpool (Apapa)	1	S64	0
2026-05-19 14:13:19.872748	T64_1_336	R64	SVC_1111110	Liverpool (Apapa)	1	S64	0
2026-05-19 14:13:19.872748	T64_1_338	R64	SVC_1111110	Liverpool (Apapa)	1	S64	0
2026-05-19 14:13:19.872748	T65_0_349	R65	SVC_0000010	Ilashe	0	S65	0
2026-05-19 14:13:19.872748	T65_0_339	R65	SVC_1111100	Ilashe	0	S65	0
2026-05-19 14:13:19.872748	T65_0_341	R65	SVC_1111100	Ilashe	0	S65	0
2026-05-19 14:13:19.872748	T65_0_351	R65	SVC_0000010	Ilashe	0	S65	0
2026-05-19 14:13:19.872748	T65_0_343	R65	SVC_1111100	Ilashe	0	S65	0
2026-05-19 14:13:19.872748	T65_0_345	R65	SVC_1111100	Ilashe	0	S65	0
2026-05-19 14:13:19.872748	T65_0_353	R65	SVC_0000010	Ilashe	0	S65	0
2026-05-19 14:13:19.872748	T65_0_347	R65	SVC_1111100	Ilashe	0	S65	0
2026-05-19 14:13:19.872748	T65_1_350	R65	SVC_0000010	Ojo market waterside	1	S65	0
2026-05-19 14:13:19.872748	T65_1_340	R65	SVC_1111100	Ojo market waterside	1	S65	0
2026-05-19 14:13:19.872748	T65_1_342	R65	SVC_1111100	Ojo market waterside	1	S65	0
2026-05-19 14:13:19.872748	T65_1_344	R65	SVC_1111100	Ojo market waterside	1	S65	0
2026-05-19 14:13:19.872748	T65_1_352	R65	SVC_0000010	Ojo market waterside	1	S65	0
2026-05-19 14:13:19.872748	T65_1_346	R65	SVC_1111100	Ojo market waterside	1	S65	0
2026-05-19 14:13:19.872748	T65_1_354	R65	SVC_0000010	Ojo market waterside	1	S65	0
2026-05-19 14:13:19.872748	T65_1_348	R65	SVC_1111100	Ojo market waterside	1	S65	0
2026-05-19 14:13:19.872748	T66_0_355	R66	SVC_1111110	Ojo market waterside	0	S66	0
2026-05-19 14:13:19.872748	T66_0_357	R66	SVC_1111110	Ojo market waterside	0	S66	0
2026-05-19 14:13:19.872748	T66_0_359	R66	SVC_1111110	Ojo market waterside	0	S66	0
2026-05-19 14:13:19.872748	T66_1_356	R66	SVC_1111110	Iyagbe	1	S66	0
2026-05-19 14:13:19.872748	T66_1_358	R66	SVC_1111110	Iyagbe	1	S66	0
2026-05-19 14:13:19.872748	T66_1_360	R66	SVC_1111110	Iyagbe	1	S66	0
2026-05-19 14:13:19.872748	T67_0_361	R67	SVC_1111110	Ojo market waterside	0	S67	0
2026-05-19 14:13:19.872748	T67_0_363	R67	SVC_1111110	Ojo market waterside	0	S67	0
2026-05-19 14:13:19.872748	T67_0_365	R67	SVC_1111110	Ojo market waterside	0	S67	0
2026-05-19 14:13:19.872748	T67_1_362	R67	SVC_1111110	Ikare palace	1	S67	0
2026-05-19 14:13:19.872748	T67_1_364	R67	SVC_1111110	Ikare palace	1	S67	0
2026-05-19 14:13:19.872748	T67_1_366	R67	SVC_1111110	Ikare palace	1	S67	0
2026-05-19 14:13:19.872748	T68_0_367	R68	SVC_1111110	Ojo market waterside	0	S68	0
2026-05-19 14:13:19.872748	T68_0_369	R68	SVC_1111110	Ojo market waterside	0	S68	0
2026-05-19 14:13:19.872748	T68_0_371	R68	SVC_1111110	Ojo market waterside	0	S68	0
2026-05-19 14:13:19.872748	T68_1_368	R68	SVC_1111110	Ikare town landing	1	S68	0
2026-05-19 14:13:19.872748	T68_1_370	R68	SVC_1111110	Ikare town landing	1	S68	0
2026-05-19 14:13:19.872748	T68_1_372	R68	SVC_1111110	Ikare town landing	1	S68	0
2026-05-19 14:13:19.872748	T71_0_376	R71	SVC_1111100	Ijegun Egba	0	S71	0
2026-05-19 14:13:19.872748	T71_0_384	R71	SVC_0000010	Ijegun Egba	0	S71	0
2026-05-19 14:13:19.872748	T71_0_378	R71	SVC_1111100	Ijegun Egba	0	S71	0
2026-05-19 14:13:19.872748	T71_0_386	R71	SVC_0000010	Ijegun Egba	0	S71	0
2026-05-19 14:13:19.872748	T71_0_380	R71	SVC_1111100	Ijegun Egba	0	S71	0
2026-05-19 14:13:19.872748	T71_0_382	R71	SVC_1111100	Ijegun Egba	0	S71	0
2026-05-19 14:13:19.872748	T71_1_385	R71	SVC_0000010	Ibese	1	S71	0
2026-05-19 14:13:19.872748	T71_1_377	R71	SVC_1111100	Ibese	1	S71	0
2026-05-19 14:13:19.872748	T71_1_379	R71	SVC_1111100	Ibese	1	S71	0
2026-05-19 14:13:19.872748	T71_1_387	R71	SVC_0000010	Ibese	1	S71	0
2026-05-19 14:13:19.872748	T71_1_381	R71	SVC_1111100	Ibese	1	S71	0
2026-05-19 14:13:19.872748	T71_1_383	R71	SVC_1111100	Ibese	1	S71	0
2026-05-19 14:13:19.872748	T72_0_388	R72	SVC_1111110	Badore Ferry Terminal	0	S72	0
2026-05-19 14:13:19.872748	T72_0_390	R72	SVC_1111110	Badore Ferry Terminal	0	S72	0
2026-05-19 14:13:19.872748	T72_0_392	R72	SVC_1111110	Badore Ferry Terminal	0	S72	0
2026-05-19 14:13:19.872748	T72_1_389	R72	SVC_1111110	Addax/Sandfill/Maroko (Victoria Island)	1	S72	0
2026-05-19 14:13:19.872748	T72_1_391	R72	SVC_1111110	Addax/Sandfill/Maroko (Victoria Island)	1	S72	0
2026-05-19 14:13:19.872748	T72_1_393	R72	SVC_1111110	Addax/Sandfill/Maroko (Victoria Island)	1	S72	0
2026-05-19 14:13:19.872748	T121_0_592	R121	SVC_1111110	Kirikiri	0	S121	0
2026-05-19 14:13:19.872748	T73_0_918	R73	SVC_1111110	Ikorodu/Ipakodo Ferry Terminal	0	S73	0
2026-05-19 14:13:19.872748	T73_1_917	R73	SVC_1111110	Addax/Sandfill/Maroko (Victoria Island)	1	S73	0
2026-05-19 14:13:19.872748	T74_0_920	R74	SVC_1111110	Baiyeku	0	S74	0
2026-05-19 14:13:19.872748	T74_1_919	R74	SVC_1111110	Addax/Sandfill/Maroko (Victoria Island)	1	S74	0
2026-05-19 14:13:19.872748	T75_0_406	R75	SVC_1111110	Ikorodu/Ipakodo Ferry Terminal	0	S75	0
2026-05-19 14:13:19.872748	T75_0_408	R75	SVC_1111110	Ikorodu/Ipakodo Ferry Terminal	0	S75	0
2026-05-19 14:13:19.872748	T75_0_410	R75	SVC_1111110	Ikorodu/Ipakodo Ferry Terminal	0	S75	0
2026-05-19 14:13:19.872748	T75_1_407	R75	SVC_1111110	Flour Mills (Apapa)	1	S75	0
2026-05-19 14:13:19.872748	T75_1_409	R75	SVC_1111110	Flour Mills (Apapa)	1	S75	0
2026-05-19 14:13:19.872748	T75_1_411	R75	SVC_1111110	Flour Mills (Apapa)	1	S75	0
2026-05-19 14:13:19.872748	T76_0_654	R76	SVC_1111110	Marina/CMS	0	S76	0
2026-05-19 14:13:19.872748	T76_0_656	R76	SVC_1111110	Marina/CMS	0	S76	0
2026-05-19 14:13:19.872748	T76_0_658	R76	SVC_1111110	Marina/CMS	0	S76	0
2026-05-19 14:13:19.872748	T76_0_660	R76	SVC_1111110	Marina/CMS	0	S76	0
2026-05-19 14:13:19.872748	T76_1_655	R76	SVC_1111110	Flour Mills (Apapa)	1	S76	0
2026-05-19 14:13:19.872748	T76_1_657	R76	SVC_1111110	Flour Mills (Apapa)	1	S76	0
2026-05-19 14:13:19.872748	T76_1_659	R76	SVC_1111110	Flour Mills (Apapa)	1	S76	0
2026-05-19 14:13:19.872748	T76_1_661	R76	SVC_1111110	Flour Mills (Apapa)	1	S76	0
2026-05-19 14:13:19.872748	T77_0_418	R77	SVC_1111110	Mile 2/NIWA	0	S77	0
2026-05-19 14:13:19.872748	T77_0_420	R77	SVC_1111110	Mile 2/NIWA	0	S77	0
2026-05-19 14:13:19.872748	T77_0_422	R77	SVC_1111110	Mile 2/NIWA	0	S77	0
2026-05-19 14:13:19.872748	T77_1_419	R77	SVC_1111110	Capital Oil/FESTAC	1	S77	0
2026-05-19 14:13:19.872748	T77_1_421	R77	SVC_1111110	Capital Oil/FESTAC	1	S77	0
2026-05-19 14:13:19.872748	T77_1_423	R77	SVC_1111110	Capital Oil/FESTAC	1	S77	0
2026-05-19 14:13:19.872748	T89_0_483	R89	SVC_1111100	Ijede/Tarzan	0	S89	0
2026-05-19 14:13:19.872748	T89_1_482	R89	SVC_1111100	Badore Ferry Terminal	1	S89	0
2026-05-19 14:13:19.872748	T90_0_484	R90	SVC_1111100	Five Cowries/Falomo (Ikoyi)	0	S90	0
2026-05-19 14:13:19.872748	T90_1_485	R90	SVC_1111100	Badore Ferry Terminal	1	S90	0
2026-05-19 14:13:19.872748	T91_0_487	R91	SVC_1111100	Gberigbe	0	S91	0
2026-05-19 14:13:19.872748	T91_1_486	R91	SVC_1111100	Badore Ferry Terminal	1	S91	0
2026-05-19 14:13:19.872748	T92_0_488	R92	SVC_1111100	Itomu Jetty	0	S92	0
2026-05-19 14:13:19.872748	T92_1_489	R92	SVC_1111100	Badore Ferry Terminal	1	S92	0
2026-05-19 14:13:19.872748	T94_0_492	R94	SVC_1111110	Kabiyesi itomu jetty	0	S94	0
2026-05-19 14:13:19.872748	T94_1_493	R94	SVC_1111110	Itomu Jetty	1	S94	0
2026-05-19 14:13:19.872748	T95_0_494	R95	SVC_1111110	Ipare (Ondo)	0	S95	0
2026-05-19 14:13:19.872748	T96_0_495	R96	SVC_1111110	Iwopin (Ogun)	0	S96	0
2026-05-19 14:13:19.872748	T97_0_496	R97	SVC_1111110	Abomiti-Nla Epe	0	S97	0
2026-05-19 14:13:19.872748	T98_0_497	R98	SVC_1111110	Eyin Osa	0	S98	0
2026-05-19 14:13:19.872748	T98_0_499	R98	SVC_1111110	Eyin Osa	0	S98	0
2026-05-19 14:13:19.872748	T98_1_498	R98	SVC_1111110	Epe Ayetoro Jetty	1	S98	0
2026-05-19 14:13:19.872748	T98_1_500	R98	SVC_1111110	Epe Ayetoro Jetty	1	S98	0
2026-05-19 14:13:19.872748	T103_0_509	R103	SVC_1111110	Marina/CMS	0	S103	0
2026-05-19 14:13:19.872748	T107_0_513	R107	SVC_1111110	Marina/CMS	0	S107	0
2026-05-19 14:13:19.872748	T108_0_519	R108	SVC_1111110	Marina/CMS	0	S108	0
2026-05-19 14:13:19.872748	T108_0_521	R108	SVC_1111110	Marina/CMS	0	S108	0
2026-05-19 14:13:19.872748	T108_1_520	R108	SVC_1111110	Kirikiri	1	S108	0
2026-05-19 14:13:19.872748	T108_1_522	R108	SVC_1111110	Kirikiri	1	S108	0
2026-05-19 14:13:19.872748	T108_1_523	R108	SVC_1111110	Kirikiri	1	S108	0
2026-05-19 14:13:19.872748	T109_0_524	R109	SVC_1111110	Mile 2/NIWA	0	S109	0
2026-05-19 14:13:19.872748	T109_0_526	R109	SVC_1111110	Mile 2/NIWA	0	S109	0
2026-05-19 14:13:19.872748	T109_1_525	R109	SVC_1111110	Kirikiri	1	S109	0
2026-05-19 14:13:19.872748	T109_1_527	R109	SVC_1111110	Kirikiri	1	S109	0
2026-05-19 14:13:19.872748	T109_1_528	R109	SVC_1111110	Kirikiri	1	S109	0
2026-05-19 14:13:19.872748	T111_0_530	R111	SVC_1111110	Ilashe	0	S111	0
2026-05-19 14:13:19.872748	T111_0_532	R111	SVC_1111110	Ilashe	0	S111	0
2026-05-19 14:13:19.872748	T111_0_534	R111	SVC_1111110	Ilashe	0	S111	0
2026-05-19 14:13:19.872748	T111_1_531	R111	SVC_1111110	Ojo market waterside	1	S111	0
2026-05-19 14:13:19.872748	T111_1_533	R111	SVC_1111110	Ojo market waterside	1	S111	0
2026-05-19 14:13:19.872748	T111_1_535	R111	SVC_1111110	Ojo market waterside	1	S111	0
2026-05-19 14:13:19.872748	T112_0_536	R112	SVC_1111110	Ibese	0	S112	0
2026-05-19 14:13:19.872748	T112_1_537	R112	SVC_1111110	Ojo market waterside	1	S112	0
2026-05-19 14:13:19.872748	T113_0_538	R113	SVC_1111110	Ikare town landing	0	S113	0
2026-05-19 14:13:19.872748	T113_0_540	R113	SVC_1111110	Ikare town landing	0	S113	0
2026-05-19 14:13:19.872748	T113_0_542	R113	SVC_1111110	Ikare town landing	0	S113	0
2026-05-19 14:13:19.872748	T113_1_539	R113	SVC_1111110	Ojo market waterside	1	S113	0
2026-05-19 14:13:19.872748	T113_1_541	R113	SVC_1111110	Ojo market waterside	1	S113	0
2026-05-19 14:13:19.872748	T113_1_543	R113	SVC_1111110	Ojo market waterside	1	S113	0
2026-05-19 14:13:19.872748	T115_0_552	R115	SVC_1111110	Agaja	0	S115	0
2026-05-19 14:13:19.872748	T115_0_554	R115	SVC_1111110	Agaja	0	S115	0
2026-05-19 14:13:19.872748	T115_0_556	R115	SVC_1111110	Agaja	0	S115	0
2026-05-19 14:13:19.872748	T115_0_558	R115	SVC_1111110	Agaja	0	S115	0
2026-05-19 14:13:19.872748	T115_1_553	R115	SVC_1111110	Ojo market waterside	1	S115	0
2026-05-19 14:13:19.872748	T115_1_555	R115	SVC_1111110	Ojo market waterside	1	S115	0
2026-05-19 14:13:19.872748	T115_1_557	R115	SVC_1111110	Ojo market waterside	1	S115	0
2026-05-19 14:13:19.872748	T115_1_559	R115	SVC_1111110	Ojo market waterside	1	S115	0
2026-05-19 14:13:19.872748	T116_0_560	R116	SVC_1111110	Port Novo (Benin Republic)	0	S116	0
2026-05-19 14:13:19.872748	T116_1_561	R116	SVC_1111110	Kirikiri	1	S116	0
2026-05-19 14:13:19.872748	T121_0_594	R121	SVC_1111110	Kirikiri	0	S121	0
2026-05-19 14:13:19.872748	T121_0_596	R121	SVC_1111110	Kirikiri	0	S121	0
2026-05-19 14:13:19.872748	T121_1_593	R121	SVC_1111110	Capital Oil/FESTAC	1	S121	0
2026-05-19 14:13:19.872748	T121_1_595	R121	SVC_1111110	Capital Oil/FESTAC	1	S121	0
2026-05-19 14:13:19.872748	T121_1_597	R121	SVC_1111110	Capital Oil/FESTAC	1	S121	0
2026-05-19 14:13:19.872748	T122_0_604	R122	SVC_1111110	Liverpool (Apapa)	0	S122	0
2026-05-19 14:13:19.872748	T122_0_606	R122	SVC_1111110	Liverpool (Apapa)	0	S122	0
2026-05-19 14:13:19.872748	T122_0_608	R122	SVC_1111110	Liverpool (Apapa)	0	S122	0
2026-05-19 14:13:19.872748	T122_1_605	R122	SVC_1111110	Capital Oil/FESTAC	1	S122	0
2026-05-19 14:13:19.872748	T122_1_607	R122	SVC_1111110	Capital Oil/FESTAC	1	S122	0
2026-05-19 14:13:19.872748	T122_1_609	R122	SVC_1111110	Capital Oil/FESTAC	1	S122	0
2026-05-19 14:13:19.872748	T123_0_610	R123	SVC_1111110	Ijegun Egba	0	S123	0
2026-05-19 14:13:19.872748	T123_0_612	R123	SVC_1111110	Ijegun Egba	0	S123	0
2026-05-19 14:13:19.872748	T123_0_614	R123	SVC_1111110	Ijegun Egba	0	S123	0
2026-05-19 14:13:19.872748	T123_1_611	R123	SVC_1111110	Kirikiri	1	S123	0
2026-05-19 14:13:19.872748	T123_1_613	R123	SVC_1111110	Kirikiri	1	S123	0
2026-05-19 14:13:19.872748	T123_1_615	R123	SVC_1111110	Kirikiri	1	S123	0
2026-05-19 14:13:19.872748	T124_0_616	R124	SVC_1111110	Ikorodu/Ipakodo Ferry Terminal	0	S124	0
2026-05-19 14:13:19.872748	T124_0_618	R124	SVC_1111110	Ikorodu/Ipakodo Ferry Terminal	0	S124	0
2026-05-19 14:13:19.872748	T124_0_620	R124	SVC_1111110	Ikorodu/Ipakodo Ferry Terminal	0	S124	0
2026-05-19 14:13:19.872748	T124_1_617	R124	SVC_1111110	Marina/CMS	1	S124	0
2026-05-19 14:13:19.872748	T124_1_619	R124	SVC_1111110	Marina/CMS	1	S124	0
2026-05-19 14:13:19.872748	T124_1_621	R124	SVC_1111110	Marina/CMS	1	S124	0
2026-05-19 14:13:19.872748	T125_0_622	R125	SVC_1111110	Tarkwa Bay	0	S125	0
2026-05-19 14:13:19.872748	T125_0_624	R125	SVC_1111110	Tarkwa Bay	0	S125	0
2026-05-19 14:13:19.872748	T125_0_626	R125	SVC_1111110	Tarkwa Bay	0	S125	0
2026-05-19 14:13:19.872748	T125_1_623	R125	SVC_1111110	Marina/CMS	1	S125	0
2026-05-19 14:13:19.872748	T125_1_625	R125	SVC_1111110	Marina/CMS	1	S125	0
2026-05-19 14:13:19.872748	T125_1_627	R125	SVC_1111110	Marina/CMS	1	S125	0
2026-05-19 14:13:19.872748	T126_0_806	R126	SVC_1111110	Port Novo (Benin Republic)	0	S126	0
2026-05-19 14:13:19.872748	T128_0_632	R128	SVC_1111110	Liverpool (Apapa)	0	S128	0
2026-05-19 14:13:19.872748	T128_1_633	R128	SVC_1111110	Marina/CMS	1	S128	0
2026-05-19 14:13:19.872748	T129_0_827	R129	SVC_1111111	Sagbokoji	0	S129	0
2026-05-19 14:13:19.872748	T129_0_829	R129	SVC_1111111	Sagbokoji	0	S129	0
2026-05-19 14:13:19.872748	T129_0_831	R129	SVC_1111111	Sagbokoji	0	S129	0
2026-05-19 14:13:19.872748	T129_1_828	R129	SVC_1111111	Marina/CMS	1	S129	0
2026-05-19 14:13:19.872748	T129_1_830	R129	SVC_1111111	Marina/CMS	1	S129	0
2026-05-19 14:13:19.872748	T129_1_832	R129	SVC_1111111	Marina/CMS	1	S129	0
2026-05-19 14:13:19.872748	T131_0_638	R131	SVC_1111110	Number 1A Waterside	0	S131	0
2026-05-19 14:13:19.872748	T131_0_640	R131	SVC_1111110	Number 1A Waterside	0	S131	0
2026-05-19 14:13:19.872748	T131_0_642	R131	SVC_1111110	Number 1A Waterside	0	S131	0
2026-05-19 14:13:19.872748	T131_0_644	R131	SVC_1111110	Number 1A Waterside	0	S131	0
2026-05-19 14:13:19.872748	T131_1_639	R131	SVC_1111110	Second Badagry	1	S131	0
2026-05-19 14:13:19.872748	T131_1_641	R131	SVC_1111110	Second Badagry	1	S131	0
2026-05-19 14:13:19.872748	T131_1_643	R131	SVC_1111110	Second Badagry	1	S131	0
2026-05-19 14:13:19.872748	T131_1_645	R131	SVC_1111110	Second Badagry	1	S131	0
2026-05-19 14:13:19.872748	T132_0_646	R132	SVC_1111110	Number 1A Waterside	0	S132	0
2026-05-19 14:13:19.872748	T132_0_648	R132	SVC_1111110	Number 1A Waterside	0	S132	0
2026-05-19 14:13:19.872748	T132_0_650	R132	SVC_1111110	Number 1A Waterside	0	S132	0
2026-05-19 14:13:19.872748	T132_0_652	R132	SVC_1111110	Number 1A Waterside	0	S132	0
2026-05-19 14:13:19.872748	T132_1_647	R132	SVC_1111110	Mogaji (Ajegunle)	1	S132	0
2026-05-19 14:13:19.872748	T132_1_649	R132	SVC_1111110	Mogaji (Ajegunle)	1	S132	0
2026-05-19 14:13:19.872748	T132_1_651	R132	SVC_1111110	Mogaji (Ajegunle)	1	S132	0
2026-05-19 14:13:19.872748	T132_1_653	R132	SVC_1111110	Mogaji (Ajegunle)	1	S132	0
2026-05-19 14:13:19.872748	T135_0_678	R135	SVC_1111110	Number 2 (Ajegunle) Waterside/Kumuyi Street(Ajegunle)	0	S135	0
2026-05-19 14:13:19.872748	T135_0_680	R135	SVC_1111110	Number 2 (Ajegunle) Waterside/Kumuyi Street(Ajegunle)	0	S135	0
2026-05-19 14:13:19.872748	T135_0_682	R135	SVC_1111110	Number 2 (Ajegunle) Waterside/Kumuyi Street(Ajegunle)	0	S135	0
2026-05-19 14:13:19.872748	T135_0_684	R135	SVC_1111110	Number 2 (Ajegunle) Waterside/Kumuyi Street(Ajegunle)	0	S135	0
2026-05-19 14:13:19.872748	T135_1_679	R135	SVC_1111110	Number 2 (Apapa) Waterside	1	S135	0
2026-05-19 14:13:19.872748	T135_1_681	R135	SVC_1111110	Number 2 (Apapa) Waterside	1	S135	0
2026-05-19 14:13:19.872748	T135_1_683	R135	SVC_1111110	Number 2 (Apapa) Waterside	1	S135	0
2026-05-19 14:13:19.872748	T135_1_685	R135	SVC_1111110	Number 2 (Apapa) Waterside	1	S135	0
2026-05-19 14:13:19.872748	T136_0_686	R136	SVC_1111110	Badore Ferry Terminal	0	S136	0
2026-05-19 14:13:19.872748	T136_1_687	R136	SVC_1111110	Marina/CMS	1	S136	0
2026-05-19 14:13:19.872748	T138_0_696	R138	SVC_1111110	Number 3 (Ajegunle) Waterside	0	S138	0
2026-05-19 14:13:19.872748	T138_0_698	R138	SVC_1111110	Number 3 (Ajegunle) Waterside	0	S138	0
2026-05-19 14:13:19.872748	T138_0_700	R138	SVC_1111110	Number 3 (Ajegunle) Waterside	0	S138	0
2026-05-19 14:13:19.872748	T138_0_702	R138	SVC_1111110	Number 3 (Ajegunle) Waterside	0	S138	0
2026-05-19 14:13:19.872748	T138_1_697	R138	SVC_1111110	Boundary (Apapa)/Number 3 (Apapa) Waterside	1	S138	0
2026-05-19 14:13:19.872748	T138_1_699	R138	SVC_1111110	Boundary (Apapa)/Number 3 (Apapa) Waterside	1	S138	0
2026-05-19 14:13:19.872748	T138_1_701	R138	SVC_1111110	Boundary (Apapa)/Number 3 (Apapa) Waterside	1	S138	0
2026-05-19 14:13:19.872748	T138_1_703	R138	SVC_1111110	Boundary (Apapa)/Number 3 (Apapa) Waterside	1	S138	0
2026-05-19 14:13:19.872748	T140_0_720	R140	SVC_0000011	IKO/Temidire	0	S140	0
2026-05-19 14:13:19.872748	T140_0_712	R140	SVC_1111100	IKO/Temidire	0	S140	0
2026-05-19 14:13:19.872748	T140_0_714	R140	SVC_1111100	IKO/Temidire	0	S140	0
2026-05-19 14:13:19.872748	T140_0_722	R140	SVC_0000011	IKO/Temidire	0	S140	0
2026-05-19 14:13:19.872748	T140_0_716	R140	SVC_1111100	IKO/Temidire	0	S140	0
2026-05-19 14:13:19.872748	T140_0_724	R140	SVC_0000011	IKO/Temidire	0	S140	0
2026-05-19 14:13:19.872748	T140_0_726	R140	SVC_0000011	IKO/Temidire	0	S140	0
2026-05-19 14:13:19.872748	T140_0_718	R140	SVC_1111100	IKO/Temidire	0	S140	0
2026-05-19 14:13:19.872748	T140_1_721	R140	SVC_0000011	First Gate (Tin Can Island)	1	S140	0
2026-05-19 14:13:19.872748	T140_1_713	R140	SVC_1111100	First Gate (Tin Can Island)	1	S140	0
2026-05-19 14:13:19.872748	T140_1_723	R140	SVC_0000011	First Gate (Tin Can Island)	1	S140	0
2026-05-19 14:13:19.872748	T140_1_715	R140	SVC_1111100	First Gate (Tin Can Island)	1	S140	0
2026-05-19 14:13:19.872748	T140_1_717	R140	SVC_1111100	First Gate (Tin Can Island)	1	S140	0
2026-05-19 14:13:19.872748	T140_1_725	R140	SVC_0000011	First Gate (Tin Can Island)	1	S140	0
2026-05-19 14:13:19.872748	T140_1_727	R140	SVC_0000011	First Gate (Tin Can Island)	1	S140	0
2026-05-19 14:13:19.872748	T140_1_719	R140	SVC_1111100	First Gate (Tin Can Island)	1	S140	0
2026-05-19 14:13:19.872748	T142_0_769	R142	SVC_1111111	Number 1 (Apapa) Waterside	0	S142	0
2026-05-19 14:13:19.872748	T142_0_771	R142	SVC_1111111	Number 1 (Apapa) Waterside	0	S142	0
2026-05-19 14:13:19.872748	T142_0_773	R142	SVC_1111111	Number 1 (Apapa) Waterside	0	S142	0
2026-05-19 14:13:19.872748	T142_0_775	R142	SVC_1111111	Number 1 (Apapa) Waterside	0	S142	0
2026-05-19 14:13:19.872748	T142_1_770	R142	SVC_1111111	Number 1 (Ajegunle) Waterside	1	S142	0
2026-05-19 14:13:19.872748	T142_1_772	R142	SVC_1111111	Number 1 (Ajegunle) Waterside	1	S142	0
2026-05-19 14:13:19.872748	T142_1_774	R142	SVC_1111111	Number 1 (Ajegunle) Waterside	1	S142	0
2026-05-19 14:13:19.872748	T142_1_776	R142	SVC_1111111	Number 1 (Ajegunle) Waterside	1	S142	0
2026-05-19 14:13:19.872748	T144_0_760	R144	SVC_1111110	Port Novo (Benin Republic)	0	S144	0
2026-05-19 14:13:19.872748	T148_0_801	R148	SVC_1111110	Ojo market waterside	0	S148	0
2026-05-19 14:13:19.872748	T149_0_802	R149	SVC_1111111	Agojedo/Agbejedo	0	S149	0
2026-05-19 14:13:19.872748	T149_1_803	R149	SVC_1111111	Itomoro	1	S149	0
2026-05-19 14:13:19.872748	T154_0_833	R154	SVC_1111111	Ogogoro Village	0	S154	0
2026-05-19 14:13:19.872748	T155_0_835	R155	SVC_1111110	Marina/CMS	0	S155	0
2026-05-19 14:13:19.872748	T156_0_836	R156	SVC_1111110	Ebute Ero/Elegbata Jetty	0	S156	0
2026-05-19 14:13:19.872748	T157_0_837	R157	SVC_1111110	Ebute Ero/Elegbata Jetty	0	S157	0
2026-05-19 14:13:19.872748	T158_0_838	R158	SVC_1111110	Izigi (Ogun)	0	S158	0
2026-05-19 14:13:19.872748	T158_1_839	R158	SVC_1111110	Iya Afin Jetty	1	S158	0
2026-05-19 14:13:19.872748	T159_0_922	R159	SVC_1111110	Ibeshe/Thesaurus Ferry Terminal	0	S159	0
2026-05-19 14:13:19.872748	T159_1_921	R159	SVC_1111110	Addax/Sandfill/Maroko (Victoria Island)	1	S159	0
2026-05-19 14:13:19.872748	T160_0_924	R160	SVC_1111110	Offin, Ikorodu	0	S160	0
2026-05-19 14:13:19.872748	T160_1_923	R160	SVC_1111110	Addax/Sandfill/Maroko (Victoria Island)	1	S160	0
2026-05-19 14:13:19.872748	T161_0_926	R161	SVC_1111110	Ijede/Tarzan	0	S161	0
2026-05-19 14:13:19.872748	T161_1_925	R161	SVC_1111110	Addax/Sandfill/Maroko (Victoria Island)	1	S161	0
2026-05-19 14:13:19.872748	T162_0_860	R162	SVC_1111110	Liverpool (Apapa)	0	S162	0
2026-05-19 14:13:19.872748	T162_0_862	R162	SVC_1111110	Liverpool (Apapa)	0	S162	0
2026-05-19 14:13:19.872748	T162_0_864	R162	SVC_1111110	Liverpool (Apapa)	0	S162	0
2026-05-19 14:13:19.872748	T162_1_861	R162	SVC_1111110	Igbo Elejo	1	S162	0
2026-05-19 14:13:19.872748	T162_1_863	R162	SVC_1111110	Igbo Elejo	1	S162	0
2026-05-19 14:13:19.872748	T162_1_865	R162	SVC_1111110	Igbo Elejo	1	S162	0
2026-05-19 14:13:19.872748	T163_0_866	R163	SVC_1111110	Isoda	0	S163	0
2026-05-19 14:13:19.872748	T163_0_868	R163	SVC_1111110	Isoda	0	S163	0
2026-05-19 14:13:19.872748	T163_0_870	R163	SVC_1111110	Isoda	0	S163	0
2026-05-19 14:13:19.872748	T163_1_867	R163	SVC_1111110	Igbo Elejo	1	S163	0
2026-05-19 14:13:19.872748	T163_1_869	R163	SVC_1111110	Igbo Elejo	1	S163	0
2026-05-19 14:13:19.872748	T163_1_871	R163	SVC_1111110	Igbo Elejo	1	S163	0
2026-05-19 14:13:19.872748	T164_0_872	R164	SVC_1111110	Liverpool (Apapa)	0	S164	0
2026-05-19 14:13:19.872748	T164_0_874	R164	SVC_1111110	Liverpool (Apapa)	0	S164	0
2026-05-19 14:13:19.872748	T164_0_876	R164	SVC_1111110	Liverpool (Apapa)	0	S164	0
2026-05-19 14:13:19.872748	T164_0_878	R164	SVC_1111110	Liverpool (Apapa)	0	S164	0
2026-05-19 14:13:19.872748	T164_1_873	R164	SVC_1111110	Isoda	1	S164	0
2026-05-19 14:13:19.872748	T164_1_875	R164	SVC_1111110	Isoda	1	S164	0
2026-05-19 14:13:19.872748	T164_1_877	R164	SVC_1111110	Isoda	1	S164	0
2026-05-19 14:13:19.872748	T164_1_879	R164	SVC_1111110	Isoda	1	S164	0
2026-05-19 14:13:19.872748	T165_0_880	R165	SVC_1111110	Isoda	0	S165	0
2026-05-19 14:13:19.872748	T165_1_881	R165	SVC_1111110	Ilutuntun	1	S165	0
2026-05-19 14:13:19.872748	T166_0_882	R166	SVC_1111110	Liverpool (Apapa)	0	S166	0
2026-05-19 14:13:19.872748	T166_0_884	R166	SVC_1111110	Liverpool (Apapa)	0	S166	0
2026-05-19 14:13:19.872748	T166_0_886	R166	SVC_1111110	Liverpool (Apapa)	0	S166	0
2026-05-19 14:13:19.872748	T166_0_888	R166	SVC_1111110	Liverpool (Apapa)	0	S166	0
2026-05-19 14:13:19.872748	T166_1_883	R166	SVC_1111110	Itomoro	1	S166	0
2026-05-19 14:13:19.872748	T166_1_885	R166	SVC_1111110	Itomoro	1	S166	0
2026-05-19 14:13:19.872748	T166_1_887	R166	SVC_1111110	Itomoro	1	S166	0
2026-05-19 14:13:19.872748	T166_1_889	R166	SVC_1111110	Itomoro	1	S166	0
2026-05-19 14:13:19.872748	T168_0_894	R168	SVC_1111110	Ojo market waterside	0	S168	0
2026-05-19 14:13:19.872748	T168_0_896	R168	SVC_1111110	Ojo market waterside	0	S168	0
2026-05-19 14:13:19.872748	T168_1_895	R168	SVC_1111110	Irewe Ojo	1	S168	0
2026-05-19 14:13:19.872748	T168_1_897	R168	SVC_1111110	Irewe Ojo	1	S168	0
2026-05-19 14:13:19.872748	T170_0_906	R170	SVC_0000011	Tarkwa Bay	0	S170	0
2026-05-19 14:13:19.872748	T179_0_898	R179	SVC_1111111	Oko Agbon	0	S179	0
2026-05-19 14:13:19.872748	T179_1_899	R179	SVC_1111111	Agboyi Ketu	1	S179	0
2026-05-19 14:13:19.872748	T180_0_900	R180	SVC_1111111	Egan Landing	0	S180	0
2026-05-19 14:13:19.872748	T180_0_901	R180	SVC_1111111	Egan Landing	0	S180	0
2026-05-19 14:13:19.872748	T180_0_902	R180	SVC_1111111	Egan Landing	0	S180	0
2026-05-19 14:13:19.872748	T180_1_903	R180	SVC_1111111	Etegbin	1	S180	0
2026-05-19 14:13:19.872748	T180_1_904	R180	SVC_1111111	Etegbin	1	S180	0
2026-05-19 14:13:19.872748	T180_1_905	R180	SVC_1111111	Etegbin	1	S180	0
2026-05-19 14:13:19.872748	T181_0_907	R181	SVC_1111110	Imore Community	0	S181	0
2026-05-19 14:13:19.872748	T181_0_909	R181	SVC_1111110	Imore Community	0	S181	0
2026-05-19 14:13:19.872748	T181_0_913	R181	SVC_1111110	Imore Community	0	S181	0
2026-05-19 14:13:19.872748	T181_0_915	R181	SVC_1111110	Imore Community	0	S181	0
2026-05-19 14:13:19.872748	T181_1_908	R181	SVC_1111110	Imore Waterside	1	S181	0
2026-05-19 14:13:19.872748	T181_1_910	R181	SVC_1111110	Imore Waterside	1	S181	0
2026-05-19 14:13:19.872748	T181_1_914	R181	SVC_1111110	Imore Waterside	1	S181	0
2026-05-19 14:13:19.872748	T181_1_916	R181	SVC_1111110	Imore Waterside	1	S181	0
\.


--
-- Name: replit_database_migrations_v1_id_seq; Type: SEQUENCE SET; Schema: _system; Owner: -
--

SELECT pg_catalog.setval('_system.replit_database_migrations_v1_id_seq', 3, true);


--
-- Name: facilities_facility_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.facilities_facility_id_seq', 222, true);


--
-- Name: facility_destinations_facility_destination_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.facility_destinations_facility_destination_id_seq', 676, true);


--
-- Name: facility_submissions_facility_submission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.facility_submissions_facility_submission_id_seq', 228, true);


--
-- Name: route_periods_route_period_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.route_periods_route_period_id_seq', 926, true);


--
-- Name: route_stops_route_stop_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.route_stops_route_stop_id_seq', 570, true);


--
-- Name: route_submissions_route_submission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.route_submissions_route_submission_id_seq', 205, true);


--
-- Name: routes_route_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.routes_route_id_seq', 181, true);


--
-- Name: replit_database_migrations_v1 replit_database_migrations_v1_pkey; Type: CONSTRAINT; Schema: _system; Owner: -
--

ALTER TABLE ONLY _system.replit_database_migrations_v1
    ADD CONSTRAINT replit_database_migrations_v1_pkey PRIMARY KEY (id);


--
-- Name: facilities facilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facilities
    ADD CONSTRAINT facilities_pkey PRIMARY KEY (facility_id);


--
-- Name: facility_destinations facility_destinations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_destinations
    ADD CONSTRAINT facility_destinations_pkey PRIMARY KEY (facility_destination_id);


--
-- Name: facility_submissions facility_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_submissions
    ADD CONSTRAINT facility_submissions_pkey PRIMARY KEY (facility_submission_id);


--
-- Name: route_periods route_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_periods
    ADD CONSTRAINT route_periods_pkey PRIMARY KEY (route_period_id);


--
-- Name: route_stops route_stops_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_stops
    ADD CONSTRAINT route_stops_pkey PRIMARY KEY (route_stop_id);


--
-- Name: route_submissions route_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_submissions
    ADD CONSTRAINT route_submissions_pkey PRIMARY KEY (route_submission_id);


--
-- Name: routes routes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_pkey PRIMARY KEY (route_id);


--
-- Name: idx_replit_database_migrations_v1_build_id; Type: INDEX; Schema: _system; Owner: -
--

CREATE UNIQUE INDEX idx_replit_database_migrations_v1_build_id ON _system.replit_database_migrations_v1 USING btree (build_id);


--
-- Name: route_stops trigger_sync_route_stops; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_sync_route_stops AFTER INSERT OR DELETE OR UPDATE ON public.route_stops FOR EACH ROW EXECUTE FUNCTION public.update_route_stop_names();


--
-- Name: facility_destinations facility_destinations_destination_id_facilities_facility_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_destinations
    ADD CONSTRAINT facility_destinations_destination_id_facilities_facility_id_fk FOREIGN KEY (destination_id) REFERENCES public.facilities(facility_id) ON DELETE CASCADE;


--
-- Name: facility_destinations facility_destinations_facility_id_facilities_facility_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_destinations
    ADD CONSTRAINT facility_destinations_facility_id_facilities_facility_id_fk FOREIGN KEY (facility_id) REFERENCES public.facilities(facility_id) ON DELETE CASCADE;


--
-- Name: facility_submissions facility_submissions_facility_id_facilities_facility_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_submissions
    ADD CONSTRAINT facility_submissions_facility_id_facilities_facility_id_fk FOREIGN KEY (facility_id) REFERENCES public.facilities(facility_id) ON DELETE CASCADE;


--
-- Name: route_periods route_periods_route_id_routes_route_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_periods
    ADD CONSTRAINT route_periods_route_id_routes_route_id_fk FOREIGN KEY (route_id) REFERENCES public.routes(route_id) ON DELETE CASCADE;


--
-- Name: route_stops route_stops_route_id_routes_route_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_stops
    ADD CONSTRAINT route_stops_route_id_routes_route_id_fk FOREIGN KEY (route_id) REFERENCES public.routes(route_id) ON DELETE CASCADE;


--
-- Name: route_stops route_stops_stop_id_facilities_facility_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_stops
    ADD CONSTRAINT route_stops_stop_id_facilities_facility_id_fk FOREIGN KEY (stop_id) REFERENCES public.facilities(facility_id) ON DELETE CASCADE;


--
-- Name: route_submissions route_submissions_route_id_routes_route_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_submissions
    ADD CONSTRAINT route_submissions_route_id_routes_route_id_fk FOREIGN KEY (route_id) REFERENCES public.routes(route_id) ON DELETE CASCADE;


--
-- Name: routes routes_destination_facilities_facility_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_destination_facilities_facility_id_fk FOREIGN KEY (destination) REFERENCES public.facilities(facility_id);


--
-- Name: routes routes_origin_facilities_facility_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_origin_facilities_facility_id_fk FOREIGN KEY (origin) REFERENCES public.facilities(facility_id);


--
-- PostgreSQL database dump complete
--

\unrestrict y0tZIxvkbj2eOwkOjZaSs0Zk5XDkp510OF47Bh6n7vUTgev6d5EOhN09lLcqROr

