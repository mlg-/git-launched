DROP TABLE IF EXISTS launchers CASCADE;
DROP TABLE IF EXISTS starred_repos CASCADE;

CREATE TABLE launchers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  username VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE starred_repos (
  id SERIAL PRIMARY KEY,
  github_id INT,
  name VARCHAR(255),
  url VARCHAR(255),
  description VARCHAR(1000),
  launcher INT REFERENCES launchers (id) NOT NULL
);
