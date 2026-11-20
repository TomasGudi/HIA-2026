\connect mantis

--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: mantis_api_token_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_api_token_table (
    id integer NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    name character varying(128) NOT NULL,
    hash character varying(128) NOT NULL,
    date_created integer DEFAULT 1 NOT NULL,
    date_used integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_api_token_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_api_token_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_api_token_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_api_token_table_id_seq OWNED BY public.mantis_api_token_table.id;


--
-- Name: mantis_bug_file_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bug_file_table (
    id integer NOT NULL,
    bug_id integer DEFAULT 0 NOT NULL,
    title character varying(250) DEFAULT ''::character varying NOT NULL,
    description character varying(250) DEFAULT ''::character varying NOT NULL,
    diskfile character varying(250) DEFAULT ''::character varying NOT NULL,
    filename character varying(250) DEFAULT ''::character varying NOT NULL,
    folder character varying(250) DEFAULT ''::character varying NOT NULL,
    filesize integer DEFAULT 0 NOT NULL,
    file_type character varying(250) DEFAULT ''::character varying NOT NULL,
    content bytea NOT NULL,
    date_added integer DEFAULT 1 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    bugnote_id integer DEFAULT 0
);


--
-- Name: mantis_bug_file_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_bug_file_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_bug_file_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_bug_file_table_id_seq OWNED BY public.mantis_bug_file_table.id;


--
-- Name: mantis_bug_history_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bug_history_table (
    id integer NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    bug_id integer DEFAULT 0 NOT NULL,
    field_name character varying(64) DEFAULT ''::character varying NOT NULL,
    old_value character varying(255) DEFAULT ''::character varying NOT NULL,
    new_value character varying(255) DEFAULT ''::character varying NOT NULL,
    type smallint DEFAULT 0 NOT NULL,
    date_modified integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_bug_history_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_bug_history_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_bug_history_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_bug_history_table_id_seq OWNED BY public.mantis_bug_history_table.id;


--
-- Name: mantis_bug_monitor_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bug_monitor_table (
    user_id integer DEFAULT 0 NOT NULL,
    bug_id integer DEFAULT 0 NOT NULL
);


--
-- Name: mantis_bug_relationship_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bug_relationship_table (
    id integer NOT NULL,
    source_bug_id integer DEFAULT 0 NOT NULL,
    destination_bug_id integer DEFAULT 0 NOT NULL,
    relationship_type smallint DEFAULT 0 NOT NULL
);


--
-- Name: mantis_bug_relationship_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_bug_relationship_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_bug_relationship_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_bug_relationship_table_id_seq OWNED BY public.mantis_bug_relationship_table.id;


--
-- Name: mantis_bug_revision_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bug_revision_table (
    id integer NOT NULL,
    bug_id integer NOT NULL,
    bugnote_id integer DEFAULT 0 NOT NULL,
    user_id integer NOT NULL,
    type integer NOT NULL,
    value text NOT NULL,
    "timestamp" integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_bug_revision_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_bug_revision_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_bug_revision_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_bug_revision_table_id_seq OWNED BY public.mantis_bug_revision_table.id;


--
-- Name: mantis_bug_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bug_table (
    id integer NOT NULL,
    project_id integer DEFAULT 0 NOT NULL,
    reporter_id integer DEFAULT 0 NOT NULL,
    handler_id integer DEFAULT 0 NOT NULL,
    duplicate_id integer DEFAULT 0 NOT NULL,
    priority smallint DEFAULT 30 NOT NULL,
    severity smallint DEFAULT 50 NOT NULL,
    reproducibility smallint DEFAULT 10 NOT NULL,
    status smallint DEFAULT 10 NOT NULL,
    resolution smallint DEFAULT 10 NOT NULL,
    projection smallint DEFAULT 10 NOT NULL,
    eta smallint DEFAULT 10 NOT NULL,
    bug_text_id integer DEFAULT 0 NOT NULL,
    os character varying(32) DEFAULT ''::character varying NOT NULL,
    os_build character varying(32) DEFAULT ''::character varying NOT NULL,
    platform character varying(32) DEFAULT ''::character varying NOT NULL,
    version character varying(64) DEFAULT ''::character varying NOT NULL,
    fixed_in_version character varying(64) DEFAULT ''::character varying NOT NULL,
    build character varying(32) DEFAULT ''::character varying NOT NULL,
    profile_id integer DEFAULT 0 NOT NULL,
    view_state smallint DEFAULT 10 NOT NULL,
    summary character varying(128) DEFAULT ''::character varying NOT NULL,
    sponsorship_total integer DEFAULT 0 NOT NULL,
    sticky boolean DEFAULT false NOT NULL,
    target_version character varying(64) DEFAULT ''::character varying NOT NULL,
    category_id integer DEFAULT 1 NOT NULL,
    date_submitted integer DEFAULT 1 NOT NULL,
    due_date integer DEFAULT 1 NOT NULL,
    last_updated integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_bug_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_bug_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_bug_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_bug_table_id_seq OWNED BY public.mantis_bug_table.id;


--
-- Name: mantis_bug_tag_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bug_tag_table (
    bug_id integer DEFAULT 0 NOT NULL,
    tag_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    date_attached integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_bug_text_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bug_text_table (
    id integer NOT NULL,
    description text NOT NULL,
    steps_to_reproduce text NOT NULL,
    additional_information text NOT NULL
);


--
-- Name: mantis_bug_text_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_bug_text_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_bug_text_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_bug_text_table_id_seq OWNED BY public.mantis_bug_text_table.id;


--
-- Name: mantis_bugnote_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bugnote_table (
    id integer NOT NULL,
    bug_id integer DEFAULT 0 NOT NULL,
    reporter_id integer DEFAULT 0 NOT NULL,
    bugnote_text_id integer DEFAULT 0 NOT NULL,
    view_state smallint DEFAULT 10 NOT NULL,
    note_type integer DEFAULT 0,
    note_attr character varying(250) DEFAULT ''::character varying,
    time_tracking integer DEFAULT 0 NOT NULL,
    last_modified integer DEFAULT 1 NOT NULL,
    date_submitted integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_bugnote_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_bugnote_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_bugnote_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_bugnote_table_id_seq OWNED BY public.mantis_bugnote_table.id;


--
-- Name: mantis_bugnote_text_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_bugnote_text_table (
    id integer NOT NULL,
    note text NOT NULL
);


--
-- Name: mantis_bugnote_text_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_bugnote_text_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_bugnote_text_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_bugnote_text_table_id_seq OWNED BY public.mantis_bugnote_text_table.id;


--
-- Name: mantis_category_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_category_table (
    id integer NOT NULL,
    project_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    name character varying(128) DEFAULT ''::character varying NOT NULL,
    status integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_category_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_category_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_category_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_category_table_id_seq OWNED BY public.mantis_category_table.id;


--
-- Name: mantis_config_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_config_table (
    config_id character varying(64) NOT NULL,
    project_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    access_reqd integer DEFAULT 0,
    type integer DEFAULT 90,
    value text NOT NULL
);


--
-- Name: mantis_custom_field_project_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_custom_field_project_table (
    field_id integer DEFAULT 0 NOT NULL,
    project_id integer DEFAULT 0 NOT NULL,
    sequence smallint DEFAULT 0 NOT NULL
);


--
-- Name: mantis_custom_field_string_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_custom_field_string_table (
    field_id integer DEFAULT 0 NOT NULL,
    bug_id integer DEFAULT 0 NOT NULL,
    value character varying(255) DEFAULT ''::character varying NOT NULL,
    text text
);


--
-- Name: mantis_custom_field_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_custom_field_table (
    id integer NOT NULL,
    name character varying(64) DEFAULT ''::character varying NOT NULL,
    type smallint DEFAULT 0 NOT NULL,
    possible_values text DEFAULT ''::text NOT NULL,
    default_value character varying(255) DEFAULT ''::character varying NOT NULL,
    valid_regexp character varying(255) DEFAULT ''::character varying NOT NULL,
    access_level_r smallint DEFAULT 0 NOT NULL,
    access_level_rw smallint DEFAULT 0 NOT NULL,
    length_min integer DEFAULT 0 NOT NULL,
    length_max integer DEFAULT 0 NOT NULL,
    require_report boolean DEFAULT false NOT NULL,
    require_update boolean DEFAULT false NOT NULL,
    display_report boolean DEFAULT false NOT NULL,
    display_update boolean DEFAULT true NOT NULL,
    require_resolved boolean DEFAULT false NOT NULL,
    display_resolved boolean DEFAULT false NOT NULL,
    display_closed boolean DEFAULT false NOT NULL,
    require_closed boolean DEFAULT false NOT NULL,
    filter_by boolean DEFAULT true NOT NULL
);


--
-- Name: mantis_custom_field_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_custom_field_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_custom_field_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_custom_field_table_id_seq OWNED BY public.mantis_custom_field_table.id;


--
-- Name: mantis_email_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_email_table (
    email_id integer NOT NULL,
    email character varying(191) DEFAULT ''::character varying NOT NULL,
    subject character varying(250) DEFAULT ''::character varying NOT NULL,
    metadata text NOT NULL,
    body text NOT NULL,
    submitted integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_email_table_email_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_email_table_email_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_email_table_email_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_email_table_email_id_seq OWNED BY public.mantis_email_table.email_id;


--
-- Name: mantis_filters_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_filters_table (
    id integer NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    project_id integer DEFAULT 0 NOT NULL,
    is_public boolean,
    name character varying(64) DEFAULT ''::character varying NOT NULL,
    filter_string text NOT NULL
);


--
-- Name: mantis_filters_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_filters_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_filters_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_filters_table_id_seq OWNED BY public.mantis_filters_table.id;


--
-- Name: mantis_news_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_news_table (
    id integer NOT NULL,
    project_id integer DEFAULT 0 NOT NULL,
    poster_id integer DEFAULT 0 NOT NULL,
    view_state smallint DEFAULT 10 NOT NULL,
    announcement boolean DEFAULT false NOT NULL,
    headline character varying(64) DEFAULT ''::character varying NOT NULL,
    body text NOT NULL,
    last_modified integer DEFAULT 1 NOT NULL,
    date_posted integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_news_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_news_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_news_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_news_table_id_seq OWNED BY public.mantis_news_table.id;


--
-- Name: mantis_plugin_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_plugin_table (
    basename character varying(40) NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    protected boolean DEFAULT false NOT NULL,
    priority integer DEFAULT 3 NOT NULL
);


--
-- Name: mantis_project_file_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_project_file_table (
    id integer NOT NULL,
    project_id integer DEFAULT 0 NOT NULL,
    title character varying(250) DEFAULT ''::character varying NOT NULL,
    description character varying(250) DEFAULT ''::character varying NOT NULL,
    diskfile character varying(250) DEFAULT ''::character varying NOT NULL,
    filename character varying(250) DEFAULT ''::character varying NOT NULL,
    folder character varying(250) DEFAULT ''::character varying NOT NULL,
    filesize integer DEFAULT 0 NOT NULL,
    file_type character varying(250) DEFAULT ''::character varying NOT NULL,
    content bytea NOT NULL,
    date_added integer DEFAULT 1 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL
);


--
-- Name: mantis_project_file_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_project_file_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_project_file_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_project_file_table_id_seq OWNED BY public.mantis_project_file_table.id;


--
-- Name: mantis_project_hierarchy_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_project_hierarchy_table (
    child_id integer NOT NULL,
    parent_id integer NOT NULL,
    inherit_parent boolean DEFAULT false NOT NULL
);


--
-- Name: mantis_project_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_project_table (
    id integer NOT NULL,
    name character varying(128) DEFAULT ''::character varying NOT NULL,
    status smallint DEFAULT 10 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    view_state smallint DEFAULT 10 NOT NULL,
    access_min smallint DEFAULT 10 NOT NULL,
    file_path character varying(250) DEFAULT ''::character varying NOT NULL,
    description text NOT NULL,
    category_id integer DEFAULT 1 NOT NULL,
    inherit_global boolean DEFAULT false NOT NULL
);


--
-- Name: mantis_project_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_project_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_project_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_project_table_id_seq OWNED BY public.mantis_project_table.id;


--
-- Name: mantis_project_user_list_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_project_user_list_table (
    project_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    access_level smallint DEFAULT 10 NOT NULL
);


--
-- Name: mantis_project_version_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_project_version_table (
    id integer NOT NULL,
    project_id integer DEFAULT 0 NOT NULL,
    version character varying(64) DEFAULT ''::character varying NOT NULL,
    description text NOT NULL,
    released boolean DEFAULT true NOT NULL,
    obsolete boolean DEFAULT false NOT NULL,
    date_order integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_project_version_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_project_version_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_project_version_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_project_version_table_id_seq OWNED BY public.mantis_project_version_table.id;


--
-- Name: mantis_sponsorship_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_sponsorship_table (
    id integer NOT NULL,
    bug_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    logo character varying(128) DEFAULT ''::character varying NOT NULL,
    url character varying(128) DEFAULT ''::character varying NOT NULL,
    paid boolean DEFAULT false NOT NULL,
    date_submitted integer DEFAULT 1 NOT NULL,
    last_updated integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_sponsorship_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_sponsorship_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_sponsorship_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_sponsorship_table_id_seq OWNED BY public.mantis_sponsorship_table.id;


--
-- Name: mantis_tag_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_tag_table (
    id integer NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    name character varying(100) DEFAULT ''::character varying NOT NULL,
    description text NOT NULL,
    date_created integer DEFAULT 1 NOT NULL,
    date_updated integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_tag_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_tag_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_tag_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_tag_table_id_seq OWNED BY public.mantis_tag_table.id;


--
-- Name: mantis_tokens_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_tokens_table (
    id integer NOT NULL,
    owner integer NOT NULL,
    type integer NOT NULL,
    value text NOT NULL,
    "timestamp" integer DEFAULT 1 NOT NULL,
    expiry integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_tokens_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_tokens_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_tokens_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_tokens_table_id_seq OWNED BY public.mantis_tokens_table.id;


--
-- Name: mantis_user_pref_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_user_pref_table (
    id integer NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    project_id integer DEFAULT 0 NOT NULL,
    default_profile integer DEFAULT 0 NOT NULL,
    default_project integer DEFAULT 0 NOT NULL,
    refresh_delay integer DEFAULT 0 NOT NULL,
    redirect_delay integer DEFAULT 0 NOT NULL,
    bugnote_order character varying(4) DEFAULT 'ASC'::character varying NOT NULL,
    email_on_new boolean DEFAULT false NOT NULL,
    email_on_assigned boolean DEFAULT false NOT NULL,
    email_on_feedback boolean DEFAULT false NOT NULL,
    email_on_resolved boolean DEFAULT false NOT NULL,
    email_on_closed boolean DEFAULT false NOT NULL,
    email_on_reopened boolean DEFAULT false NOT NULL,
    email_on_bugnote boolean DEFAULT false NOT NULL,
    email_on_status boolean DEFAULT false NOT NULL,
    email_on_priority boolean DEFAULT false NOT NULL,
    email_on_priority_min_severity smallint DEFAULT 10 NOT NULL,
    email_on_status_min_severity smallint DEFAULT 10 NOT NULL,
    email_on_bugnote_min_severity smallint DEFAULT 10 NOT NULL,
    email_on_reopened_min_severity smallint DEFAULT 10 NOT NULL,
    email_on_closed_min_severity smallint DEFAULT 10 NOT NULL,
    email_on_resolved_min_severity smallint DEFAULT 10 NOT NULL,
    email_on_feedback_min_severity smallint DEFAULT 10 NOT NULL,
    email_on_assigned_min_severity smallint DEFAULT 10 NOT NULL,
    email_on_new_min_severity smallint DEFAULT 10 NOT NULL,
    email_bugnote_limit smallint DEFAULT 0 NOT NULL,
    language character varying(32) DEFAULT 'english'::character varying NOT NULL,
    timezone character varying(32) DEFAULT ''::character varying NOT NULL
);


--
-- Name: mantis_user_pref_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_user_pref_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_user_pref_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_user_pref_table_id_seq OWNED BY public.mantis_user_pref_table.id;


--
-- Name: mantis_user_print_pref_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_user_print_pref_table (
    user_id integer DEFAULT 0 NOT NULL,
    print_pref character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: mantis_user_profile_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_user_profile_table (
    id integer NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    platform character varying(32) DEFAULT ''::character varying NOT NULL,
    os character varying(32) DEFAULT ''::character varying NOT NULL,
    os_build character varying(32) DEFAULT ''::character varying NOT NULL,
    description text NOT NULL
);


--
-- Name: mantis_user_profile_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_user_profile_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_user_profile_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_user_profile_table_id_seq OWNED BY public.mantis_user_profile_table.id;


--
-- Name: mantis_user_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mantis_user_table (
    id integer NOT NULL,
    username character varying(191) DEFAULT ''::character varying NOT NULL,
    realname character varying(191) DEFAULT ''::character varying NOT NULL,
    email character varying(191) DEFAULT ''::character varying NOT NULL,
    password character varying(64) DEFAULT ''::character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    protected boolean DEFAULT false NOT NULL,
    access_level smallint DEFAULT 10 NOT NULL,
    login_count integer DEFAULT 0 NOT NULL,
    lost_password_request_count smallint DEFAULT 0 NOT NULL,
    failed_login_count smallint DEFAULT 0 NOT NULL,
    cookie_string character varying(64) DEFAULT ''::character varying NOT NULL,
    last_visit integer DEFAULT 1 NOT NULL,
    date_created integer DEFAULT 1 NOT NULL
);


--
-- Name: mantis_user_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mantis_user_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mantis_user_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mantis_user_table_id_seq OWNED BY public.mantis_user_table.id;


--
-- Name: mantis_api_token_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_api_token_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_api_token_table_id_seq'::regclass);


--
-- Name: mantis_bug_file_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_file_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_bug_file_table_id_seq'::regclass);


--
-- Name: mantis_bug_history_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_history_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_bug_history_table_id_seq'::regclass);


--
-- Name: mantis_bug_relationship_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_relationship_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_bug_relationship_table_id_seq'::regclass);


--
-- Name: mantis_bug_revision_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_revision_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_bug_revision_table_id_seq'::regclass);


--
-- Name: mantis_bug_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_bug_table_id_seq'::regclass);


--
-- Name: mantis_bug_text_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_text_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_bug_text_table_id_seq'::regclass);


--
-- Name: mantis_bugnote_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bugnote_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_bugnote_table_id_seq'::regclass);


--
-- Name: mantis_bugnote_text_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bugnote_text_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_bugnote_text_table_id_seq'::regclass);


--
-- Name: mantis_category_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_category_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_category_table_id_seq'::regclass);


--
-- Name: mantis_custom_field_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_custom_field_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_custom_field_table_id_seq'::regclass);


--
-- Name: mantis_email_table email_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_email_table ALTER COLUMN email_id SET DEFAULT nextval('public.mantis_email_table_email_id_seq'::regclass);


--
-- Name: mantis_filters_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_filters_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_filters_table_id_seq'::regclass);


--
-- Name: mantis_news_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_news_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_news_table_id_seq'::regclass);


--
-- Name: mantis_project_file_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_project_file_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_project_file_table_id_seq'::regclass);


--
-- Name: mantis_project_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_project_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_project_table_id_seq'::regclass);


--
-- Name: mantis_project_version_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_project_version_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_project_version_table_id_seq'::regclass);


--
-- Name: mantis_sponsorship_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_sponsorship_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_sponsorship_table_id_seq'::regclass);


--
-- Name: mantis_tag_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_tag_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_tag_table_id_seq'::regclass);


--
-- Name: mantis_tokens_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_tokens_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_tokens_table_id_seq'::regclass);


--
-- Name: mantis_user_pref_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_user_pref_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_user_pref_table_id_seq'::regclass);


--
-- Name: mantis_user_profile_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_user_profile_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_user_profile_table_id_seq'::regclass);


--
-- Name: mantis_user_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_user_table ALTER COLUMN id SET DEFAULT nextval('public.mantis_user_table_id_seq'::regclass);


--
-- Name: mantis_api_token_table mantis_api_token_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_api_token_table
    ADD CONSTRAINT mantis_api_token_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_bug_file_table mantis_bug_file_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_file_table
    ADD CONSTRAINT mantis_bug_file_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_bug_history_table mantis_bug_history_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_history_table
    ADD CONSTRAINT mantis_bug_history_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_bug_monitor_table mantis_bug_monitor_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_monitor_table
    ADD CONSTRAINT mantis_bug_monitor_table_pkey PRIMARY KEY (user_id, bug_id);


--
-- Name: mantis_bug_relationship_table mantis_bug_relationship_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_relationship_table
    ADD CONSTRAINT mantis_bug_relationship_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_bug_revision_table mantis_bug_revision_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_revision_table
    ADD CONSTRAINT mantis_bug_revision_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_bug_table mantis_bug_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_table
    ADD CONSTRAINT mantis_bug_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_bug_tag_table mantis_bug_tag_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_tag_table
    ADD CONSTRAINT mantis_bug_tag_table_pkey PRIMARY KEY (bug_id, tag_id);


--
-- Name: mantis_bug_text_table mantis_bug_text_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bug_text_table
    ADD CONSTRAINT mantis_bug_text_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_bugnote_table mantis_bugnote_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bugnote_table
    ADD CONSTRAINT mantis_bugnote_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_bugnote_text_table mantis_bugnote_text_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_bugnote_text_table
    ADD CONSTRAINT mantis_bugnote_text_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_category_table mantis_category_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_category_table
    ADD CONSTRAINT mantis_category_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_config_table mantis_config_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_config_table
    ADD CONSTRAINT mantis_config_table_pkey PRIMARY KEY (config_id, project_id, user_id);


--
-- Name: mantis_custom_field_project_table mantis_custom_field_project_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_custom_field_project_table
    ADD CONSTRAINT mantis_custom_field_project_table_pkey PRIMARY KEY (field_id, project_id);


--
-- Name: mantis_custom_field_string_table mantis_custom_field_string_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_custom_field_string_table
    ADD CONSTRAINT mantis_custom_field_string_table_pkey PRIMARY KEY (field_id, bug_id);


--
-- Name: mantis_custom_field_table mantis_custom_field_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_custom_field_table
    ADD CONSTRAINT mantis_custom_field_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_email_table mantis_email_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_email_table
    ADD CONSTRAINT mantis_email_table_pkey PRIMARY KEY (email_id);


--
-- Name: mantis_filters_table mantis_filters_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_filters_table
    ADD CONSTRAINT mantis_filters_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_news_table mantis_news_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_news_table
    ADD CONSTRAINT mantis_news_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_plugin_table mantis_plugin_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_plugin_table
    ADD CONSTRAINT mantis_plugin_table_pkey PRIMARY KEY (basename);


--
-- Name: mantis_project_file_table mantis_project_file_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_project_file_table
    ADD CONSTRAINT mantis_project_file_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_project_table mantis_project_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_project_table
    ADD CONSTRAINT mantis_project_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_project_user_list_table mantis_project_user_list_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_project_user_list_table
    ADD CONSTRAINT mantis_project_user_list_table_pkey PRIMARY KEY (project_id, user_id);


--
-- Name: mantis_project_version_table mantis_project_version_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_project_version_table
    ADD CONSTRAINT mantis_project_version_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_sponsorship_table mantis_sponsorship_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_sponsorship_table
    ADD CONSTRAINT mantis_sponsorship_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_tag_table mantis_tag_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_tag_table
    ADD CONSTRAINT mantis_tag_table_pkey PRIMARY KEY (id, name);


--
-- Name: mantis_tokens_table mantis_tokens_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_tokens_table
    ADD CONSTRAINT mantis_tokens_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_user_pref_table mantis_user_pref_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_user_pref_table
    ADD CONSTRAINT mantis_user_pref_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_user_print_pref_table mantis_user_print_pref_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_user_print_pref_table
    ADD CONSTRAINT mantis_user_print_pref_table_pkey PRIMARY KEY (user_id);


--
-- Name: mantis_user_profile_table mantis_user_profile_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_user_profile_table
    ADD CONSTRAINT mantis_user_profile_table_pkey PRIMARY KEY (id);


--
-- Name: mantis_user_table mantis_user_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mantis_user_table
    ADD CONSTRAINT mantis_user_table_pkey PRIMARY KEY (id);


--
-- Name: idx_access; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_access ON public.mantis_user_table USING btree (access_level);


--
-- Name: idx_bug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug ON public.mantis_bugnote_table USING btree (bug_id);


--
-- Name: idx_bug_file_bug_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_file_bug_id ON public.mantis_bug_file_table USING btree (bug_id);


--
-- Name: idx_bug_fixed_in_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_fixed_in_version ON public.mantis_bug_table USING btree (fixed_in_version);


--
-- Name: idx_bug_history_bug_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_history_bug_id ON public.mantis_bug_history_table USING btree (bug_id);


--
-- Name: idx_bug_history_date_modified; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_history_date_modified ON public.mantis_bug_history_table USING btree (date_modified);


--
-- Name: idx_bug_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_id ON public.mantis_bug_monitor_table USING btree (bug_id);


--
-- Name: idx_bug_rev_id_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_rev_id_time ON public.mantis_bug_revision_table USING btree (bug_id, "timestamp");


--
-- Name: idx_bug_rev_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_rev_type ON public.mantis_bug_revision_table USING btree (type);


--
-- Name: idx_bug_sponsorship_total; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_sponsorship_total ON public.mantis_bug_table USING btree (sponsorship_total);


--
-- Name: idx_bug_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_status ON public.mantis_bug_table USING btree (status);


--
-- Name: idx_bug_tag_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bug_tag_tag_id ON public.mantis_bug_tag_table USING btree (tag_id);


--
-- Name: idx_category_project_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_category_project_name ON public.mantis_category_table USING btree (project_id, name);


--
-- Name: idx_custom_field_bug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_custom_field_bug ON public.mantis_custom_field_string_table USING btree (bug_id);


--
-- Name: idx_custom_field_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_custom_field_name ON public.mantis_custom_field_table USING btree (name);


--
-- Name: idx_diskfile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_diskfile ON public.mantis_bug_file_table USING btree (diskfile);


--
-- Name: idx_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_email ON public.mantis_user_table USING btree (email);


--
-- Name: idx_enable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enable ON public.mantis_user_table USING btree (enabled);


--
-- Name: idx_history_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_history_user_id ON public.mantis_bug_history_table USING btree (user_id);


--
-- Name: idx_last_mod; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_last_mod ON public.mantis_bugnote_table USING btree (last_modified);


--
-- Name: idx_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project ON public.mantis_bug_table USING btree (project_id);


--
-- Name: idx_project_hierarchy; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_project_hierarchy ON public.mantis_project_hierarchy_table USING btree (child_id, parent_id);


--
-- Name: idx_project_hierarchy_child_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_hierarchy_child_id ON public.mantis_project_hierarchy_table USING btree (child_id);


--
-- Name: idx_project_hierarchy_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_hierarchy_parent_id ON public.mantis_project_hierarchy_table USING btree (parent_id);


--
-- Name: idx_project_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_project_name ON public.mantis_project_table USING btree (name);


--
-- Name: idx_project_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_user ON public.mantis_project_user_list_table USING btree (user_id);


--
-- Name: idx_project_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_project_version ON public.mantis_project_version_table USING btree (project_id, version);


--
-- Name: idx_project_view; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_view ON public.mantis_project_table USING btree (view_state);


--
-- Name: idx_relationship_destination; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_relationship_destination ON public.mantis_bug_relationship_table USING btree (destination_bug_id);


--
-- Name: idx_relationship_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_relationship_source ON public.mantis_bug_relationship_table USING btree (source_bug_id);


--
-- Name: idx_sponsorship_bug_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sponsorship_bug_id ON public.mantis_sponsorship_table USING btree (bug_id);


--
-- Name: idx_sponsorship_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sponsorship_user_id ON public.mantis_sponsorship_table USING btree (user_id);


--
-- Name: idx_tag_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tag_name ON public.mantis_tag_table USING btree (name);


--
-- Name: idx_typeowner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_typeowner ON public.mantis_tokens_table USING btree (type, owner);


--
-- Name: idx_user_cookie_string; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_cookie_string ON public.mantis_user_table USING btree (cookie_string);


--
-- Name: idx_user_id_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_id_name ON public.mantis_api_token_table USING btree (user_id, name);


--
-- Name: idx_user_username; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_username ON public.mantis_user_table USING btree (username);


--
-- PostgreSQL database dump complete
--


GRANT ALL ON ALL TABLES IN SCHEMA public TO mantis;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO mantis;
GRANT USAGE ON SCHEMA public TO mantis;
