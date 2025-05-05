-- CREATION OF DATASET FOR ANALYSIS
-- USERS TABLE
CREATE TABLE users (
    user_id INT PRIMARY KEY,
    signup_date DATE,
    country VARCHAR(50),
    age_group VARCHAR(20)
);

INSERT INTO users (user_id, signup_date, country, age_group) VALUES
(1, '2023-01-15', 'USA', '18-25'),
(2, '2023-02-20', 'Canada', '26-35'),
(3, '2022-11-11', 'USA', '36-45'),
(4, '2023-03-05', NULL, '26-35'),         
(5, '2023-04-01', 'India', NULL),          
(6, NULL, 'UK', '18-25'),                  
(7, '2023-02-28', 'Australia', '46-60'),
(8, '2023-05-10', 'USA', '26-35'),
(9, '2022-12-25', 'Germany', '36-45'),
(10, '2023-01-05', 'India', '18-25');

-- MOVIES TABLE
CREATE TABLE movies (
    movie_id INT PRIMARY KEY,
    title VARCHAR(100),
    genre VARCHAR(50),
    release_year INT,
    rating FLOAT
);

INSERT INTO movies (movie_id, title, genre, release_year, rating) VALUES
(1, 'Inception', 'Sci-Fi', 2010, 8.8),
(2, 'The Godfather', 'Crime', 1972, 9.2),
(3, 'Interstellar', 'Sci-Fi', 2014, 8.6),
(4, 'The Matrix', 'Action', 1999, 8.7),
(5, 'Random Movie', 'Unknown', 2027, 5.0), 
(6, 'Parasite', 'Drama', 2019, 8.6),
(7, 'Joker', 'Thriller', 2019, 8.5),
(8, 'Titanic', 'Romance', 1997, NULL),      
(9, 'Avatar', 'Fantasy', 2009, 7.8),
(10, 'Unknown Title', NULL, 2015, 6.5);     

-- VIEWS TABLE
CREATE TABLE views (
    view_id INT PRIMARY KEY,
    user_id INT,
    movie_id INT,
    watch_date DATE,
    watch_duration_minutes INT
);

INSERT INTO views (view_id, user_id, movie_id, watch_date, watch_duration_minutes) VALUES
(1, 1, 1, '2023-05-01', 120),
(2, 2, 2, '2023-05-03', 175),
(3, 3, 3, '2023-05-05', NULL),               
(4, 4, 4, NULL, 90),                         
(5, 5, 5, '2023-05-07', 110),
(6, 6, 6, '2023-04-28', 130),
(7, 7, 7, '2023-05-02', -20),                
(8, 8, 8, '2023-05-06', 195),
(9, 9, 9, '2023-05-04', 160),
(10, 10, 10, '2023-05-08', 95),
(11, 2, 1, '2023-05-09', 125),                
(12, 2, 3, NULL, NULL);  

-- Understanding & Cleaning Discrepancies
SELECT * FROM USERS LIMIT 1; 
SELECT * FROM VIEWS LIMIT 1; 
SELECT * FROM MOVIES LIMIT 1; 

SELECT * FROM USERS 
WHERE user_id is null or signup_date is null or country is null 
or age_group is null; 

SELECT * FROM VIEWS 
WHERE view_id is null or user_id is null or movie_id is null 
or watch_date is null or watch_duration_minutes is null or watch_date > current_date
or watch_duration_minutes < 0; 

SELECT * FROM MOVIES
WHERE movie_id is null or title is null or genre is null or release_year is null
or rating is null or rating < 0 or release_year > date_part('year', current_date); 

with cleaned_users as (
	select * 
	from users 
	where user_id is not null and 
	signup_date is not null and
	country is not null and 
	age_group is not null
), 
cleaned_views as (
	select * 
	from views 
	where view_id is not null and
	user_id is not null and
	movie_id is not null and 
	watch_date is not null and 
	watch_duration_minutes is not null and 
	watch_date <= current_date and 
	watch_duration_minutes >= 0
), 
cleaned_movies as (
	select * 
	from movies 
	where movie_id is not null and
	title is not null and
	genre is not null and
	release_year is not null and 
	rating is not null and 
	rating >= 0 and 
	release_year <= date_part('year', current_date)
), 
active_users_last30_days as (
	select c1.user_id, c1.country
	from cleaned_users c1
	where signup_date >= (select max(c2.signup_date) - INTERVAL '30 days' from cleaned_users c2)
)
select * 
from active_users_last30_days;

-- Materializing cleaned data views 
CREATE MATERIALIZED VIEW cleaned_users_mv AS
WITH cleaned_users AS (
    SELECT *
    FROM users
    WHERE user_id IS NOT NULL 
      AND signup_date IS NOT NULL 
      AND country IS NOT NULL 
      AND age_group IS NOT NULL
)
SELECT *
FROM cleaned_users;

select * from cleaned_users_mv limit 1; 

CREATE MATERIALIZED VIEW cleaned_views_mv as 
	with cleaned_views as (
		select * 
		from views 
		where view_id is not null and
		user_id is not null and
		movie_id is not null and 
		watch_date is not null and 
		watch_duration_minutes is not null and 
		watch_date <= current_date and 
		watch_duration_minutes >= 0
)
SELECT * from cleaned_views; 

CREATE MATERIALIZED VIEW cleaned_movies_mv as 
	with cleaned_movies as (
	select * 
		from movies 
		where movie_id is not null and
		title is not null and
		genre is not null and
		release_year is not null and 
		rating is not null and 
		rating >= 0 and 
		release_year <= date_part('year', current_date)
) 
SELECT * from cleaned_movies; 

--ANALYSIS QUESTIONS
select * from cleaned_users_mv; 
select * from cleaned_views_mv; 
select * from cleaned_movies_mv; 

-- Age group that watches movies the most
with AgegroupViewCounts as (
	select u.age_group, count(v.view_id) as total_views, 
	rank () over(order by count(v.view_id) DESC) as rnk
	from cleaned_users_mv u 
	join cleaned_views_mv v on u.user_id = v.user_id
	group by u.age_group
)
select x.age_group, x.total_views 
from AgegroupViewCounts x 
where rnk = 1; 

--Countries having highest watch time
with HighestWatchTime as (
	select u.country, sum(watch_duration_minutes) as Total_watch_time, 
	rank() over(order by sum(watch_duration_minutes) DESC) as rnk
	from cleaned_users_mv u 
	join cleaned_views_mv v on u.user_id = v.user_id 
	group by u.country
)
select country, rnk 
from HighestWatchTime; 

-- Genre Preference by Age Group
with genrepref as (
	select u.age_group, m.genre, count(*) as Total_views, 
	rank() over(partition by u.age_group, m.genre order by count(*) DESC) as rnk
	from cleaned_users_mv u 
	join cleaned_views_mv v on u.user_id = v.user_id
	join cleaned_movies_mv m on m.movie_id = v.movie_id 
	group by u.age_group, m.genre 
)
select age_group, genre, rnk as Ranking
from genrepref; 

-- Checking why every rank is 1 in genre preference in age group
SELECT u.age_group, m.genre, COUNT(*)
FROM cleaned_users_mv u
JOIN cleaned_views_mv v ON u.user_id = v.user_id
JOIN cleaned_movies_mv m ON m.movie_id = v.movie_id
GROUP BY u.age_group, m.genre
HAVING COUNT(*) > 1; -- result is none! 

-- Best Release period for New Movies 
with base_query as (
    SELECT EXTRACT(MONTH FROM watch_date) AS month, COUNT(*) AS total_views
    FROM cleaned_views_mv
    GROUP BY month
),
seasonal_views as (
    select case
                when month in (3,4,5,6) then 'Summer'
                when month in (7,8,9) then 'Monsoon'
                when month in (10,11) then 'Autumn'
                when month in (12,1,2) then 'Winter'
            end as season,
            total_views
    from base_query
)
select season, SUM(total_views) as total_views
from seasonal_views
group by season
order by SUM(total_views) DESC;

--  Top Performers vs. Sleepers
select m.title, m.movie_id
from cleaned_movies_mv m 
join cleaned_views_mv v on v.movie_id = m.movie_id 
group by m.movie_id, m.title
having sum(m.rating) > 8 and avg(v.view_id) >= count(v.view_id); 

-- User Loyalty Score
with cte as 
(select user_id, count(distinct(extract(month from watch_date))) as months from cleaned_views_mv
group by user_id) 
select user_id as loyal_user_ids
from cte 
where months >= 1; -- not relevant! 