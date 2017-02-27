drop table person cascade constraints;
create table person(id number(3) not null,
		game_id varchar(35) not null unique,
		name varchar(35) not null,
		nationality varchar(35) not null,
		primary key (id));

drop table region cascade constraints;
create table region(continent varchar(13) not null check(continent in ('Europe', 'North America')),
		primary key(continent));

drop table team cascade constraints;
create table team(t_id number(3) not null,
		tag varchar(6) not null unique,
		t_name varchar(24) not null unique,
		wins number(2) not null check(wins >= 0 and wins < 19),
		losses number(2) not null check(losses >= 0 and losses < 19),
		fundation_date date not null,
		continent varchar(13) not null,
		primary key(t_id),
		foreign key(continent) references region);

drop table player cascade constraints;
create table player(id number(3) not null,
		role varchar(8) not null check(role in ('Top', 'Jungler', 'Mid', 'AD Carry', 'Support')),
		birth_date date not null,
		t_id number(3),
		primary key(id),
		foreign key(id) references person,
		foreign key(t_id) references team);

drop table coach cascade constraints;
create table coach(id number(3) not null,
		position varchar(7) not null check(position in ('Coach', 'Analyst')),
		t_id number(3),
		primary key (id),
		foreign key (id) references person,
		foreign key(t_id) references team);

drop table brand cascade constraints;
create table brand(b_id number(3) not null,
		b_name varchar(35) not null unique,
		primary key(b_id));

drop table champion cascade constraints;
create table champion(c_id number(3) not null,
		c_name varchar(35) not null unique,
		c_role varchar(8) not null check(c_role in ('Assassin', 'Fighter', 'Mage', 'Marksman', 'Support', 'Tank')),
		primary key (c_id));

drop table patch cascade constraints;
create table patch(version number(2, 1) not null check(version >= 5 and version < 6),
		primary key(version));

drop table week cascade constraints;
create table week(w_number number(2) not null check(w_number > 0 and w_number < 10),
		continent varchar(13) not null,
		version number(2, 1) not null,
		week_mvp number(3),
		primary key(w_number, continent),
		foreign key(continent) references region,
		foreign key(version) references patch,
		foreign key(week_mvp) references player);

drop table day cascade constraints;
create table day(d_number number(1) not null check(d_number > 0 and d_number < 3),
		w_number number(2) not null,
		continent varchar(13) not null,
		primary key(d_number, w_number, continent),
		foreign key(w_number, continent) references week);

drop table game cascade constraints;
create table game(code number(3) not null,
		g_date timestamp not null unique,
		g_duration number(3) check(g_duration > 0),
		d_number number(1) not null,
		w_number number(2) not null,
		continent varchar(13) not null,
		blue_t number(3) not null,
		red_t number(3) not null,
		winner_t number(3),
		primary key(code),
		foreign key(d_number, w_number, continent) references day,
		foreign key(blue_t) references team,
		foreign key(red_t) references team,
		foreign key(winner_t) references team);

drop table sponsors cascade constraints;
create table sponsors(b_id number(3) not null,
		t_id number(3) not null,
		primary key(b_id, t_id),
		foreign key(b_id) references brand,
		foreign key(t_id) references team);

drop table disables cascade constraints;
create table disables(version number(2, 1) not null,
		c_id number(3) not null,
		primary key(version, c_id),
		foreign key(version) references patch,
		foreign key(c_id) references champion);

drop table plays cascade constraints;
create table plays(id number(3) not null,
		code number(3) not null,
		kills number(2) not null check(kills >= 0),
		deaths number(2) not null check(deaths >= 0),
		assists number(2) not null check(assists >= 0),
		creeps_slain number(3) not null check(creeps_slain >= 0),
		gold number(5) not null check(gold >= 0),
		c_id number(3) not null,
		primary key(id, code),
		foreign key(id) references player,
		foreign key(code) references game,
		foreign key(c_id) references champion);


drop sequence seq_person;
create sequence seq_person increment by 1 start with 300;

drop sequence seq_champion;
create sequence seq_champion increment by 1 start with 200;


create or replace function current_age(birth_date in date)
return number is
begin
return FLOOR(MONTHS_BETWEEN(SYSDATE, birth_date)/12);
end;
/

create or replace function avg_kills(player in number)
return number is
    pkills number;
begin
    select avg(kills) into pkills from Plays p where player = p.id;

    return pkills;
end;
/

create or replace function avg_deaths(player in number)
return number is
    pdeaths number;
begin
    select avg(deaths) into pdeaths from Plays p where player = p.id;

    return pdeaths;
end;
/


create or replace function avg_assists(player in number)
return number is
    passists number;
begin
    select avg(assists) into passists from Plays p where player = p.id;

    return passists;
end;
/

create or replace function p_kda(kills in number, deaths in number, assists in number)
return number is
begin
return FLOOR((kills+assists)/deaths);
end;
/


create or replace view person_players as
select id, game_id, name, nationality, role, current_age(birth_date) as age, birth_date, t_id
from person natural inner join player;

create or replace view person_coaches as
select id, game_id, name, nationality, position, t_id
from person natural inner join coach;


create or replace trigger DeletePlayer
instead of delete on Person_players
for each row
begin
	delete from Plays
	where id = :old.id;

	delete from Player
	where id = :old.id;

	delete from Person
	where id = :old.id;
end;
/

create or replace trigger DeleteCoach
instead of delete on Person_coaches
for each row
begin
	delete from Coach
	where id = :old.id;

	delete from Person
	where id = :old.id;
end;
/

create or replace trigger InsertPlayer
instead of insert on Person_players
for each row
declare
	idkey number(3);
begin
	select seq_person.nextval into idkey from dual;

	insert into Person values(idkey, :new.game_id, :new.name, :new.nationality);

	insert into Player values(idkey, :new.role, :new.birth_date, :new.t_id);
end;
/

create or replace trigger InsertCoach
instead of insert on Person_coaches
for each row
declare
	idkey number(3);
begin
	select seq_person.nextval into idkey from dual;

	insert into Person values(idkey, :new.game_id, :new.name, :new.nationality);

	insert into Coach values(idkey, :new.position, :new.t_id);
end;
/

create or replace trigger UpdatePlayer
instead of update on Person_players
for each row
begin
	update Person
	set game_id = :new.game_id, name = :new.name, nationality = :new.nationality
	where id = :old.id;

	if :old.t_id is null then
		update Player
		set role = :new.role, birth_date = :new.birth_date, t_id = :new.t_id
		where id = :old.id;
	else
		update Player
		set role = :new.role, birth_date = :new.birth_date
		where id = :old.id;
	end if;

	if :new.t_id is null then
		update Player
		set role = :new.role, birth_date = :new.birth_date, t_id = :new.t_id
		where id = :old.id;
	end if;
end;
/

create or replace trigger UpdateCoach
instead of update on Person_coaches
for each row
begin
	update Person
	set game_id = :new.game_id, name = :new.name, nationality = :new.nationality
	where id = :old.id;

	if :old.t_id is null then
		update Coach
		set position = :new.position, t_id = :new.t_id
		where id = :old.id;
	else
		update Coach
		set position = :new.position
		where id = :old.id;
	end if;

	if :new.t_id is null then
		update Coach
		set position = :new.position, t_id = :new.t_id
		where id = :old.id;
	end if;
end;
/


create or replace trigger InsertTeam
before insert on Team
for each row
declare
	nteams number;
begin
	if :new.wins <> 0 or :new.losses <> 0 then
		raise_application_error(-20999, 'Teams cant be inserted with wins or losses.');
	end if;

	select count(*) into nteams from Team where continent = :new.continent;

	if nteams > 9 then
		raise_application_error(-20999, 'Max number of regional teams exceeded.');
	end if;
end;
/

create or replace trigger InsertGame
before insert on Game
for each row
declare
	bcontinent varchar(13);
	rcontinent varchar(13);
	ngames number;
begin
	select continent into bcontinent from Team where t_id = :new.blue_t;
	select continent into rcontinent from Team where t_id = :new.red_t;

	if bcontinent not like :new.continent or rcontinent not like :new.continent then
		raise_application_error(-20999, 'Both teams have to be from the same region as the game itself.');
	end if;

	select count(*) into ngames from Game where d_number = :new.d_number and w_number = :new.w_number and continent = :new.continent;

	if ngames > 4 then
		raise_application_error(-20999, 'Max number of daily games exceeded.');
	end if;
end;
/

create or replace trigger FirstGame
before insert on Game
for each row
declare
	n_bgames number;
	n_rgames number;
begin
	select count(*) into n_bgames from Game where d_number = :new.d_number and w_number = :new.w_number and continent = :new.continent and (blue_t = :new.blue_t or red_t = :new.blue_t);
	select count(*) into n_rgames from Game where d_number = :new.d_number and w_number = :new.w_number and continent = :new.continent and (red_t = :new.red_t or blue_t = :new.red_t);

	if n_bgames > 0 or n_rgames > 0 then
		raise_application_error(-20999, 'Neither team cant have more than a game in the same day.');
	end if;
end;
/

create or replace trigger UpdateWinsLosses
after insert on Game
for each row
begin
	update Team
	set wins = wins+1
	where t_id = :new.winner_t;

	if :new.winner_t = :new.blue_t then
		update Team
		set losses = losses+1
		where t_id = :new.red_t;
	else
		update Team
		set losses = losses+1
		where t_id = :new.blue_t;
	end if;
end;
/

create or replace trigger InsertWinningTeam
before insert on Game
for each row
begin
	if :new.winner_t is not null and :new.g_duration is null then
		raise_application_error(-20999, 'Games have to be finished before inserting the winner.');
	end if;

	if :new.winner_t is not null and :new.winner_t <> :new.blue_t and :new.winner_t <> :new.red_t then
		raise_application_error(-20999, 'The winner has to be either the blue or the red team.');
	end if;
end;
/

create or replace trigger UpdateWinningTeam
before update of winner_t on Game
for each row
begin
	if :old.winner_t is not null and :new.winner_t <> :old.winner_t then
		raise_application_error(-20999, 'Cant select the winning team twice.');
	end if;

	if :old.g_duration is null then
		raise_application_error(-20999, 'Games have to be finished before inserting the winner.');
	end if;

	if :new.winner_t <> :old.blue_t and :new.winner_t <> :old.red_t then
		raise_application_error(-20999, 'The winner has to be either the blue or the red team.');
	end if;

	update Team
	set wins = wins+1
	where t_id = :new.winner_t;

	if :new.winner_t = :new.blue_t then
		update Team
		set losses = losses+1
		where t_id = :new.red_t;
	else
		update Team
		set losses = losses+1
		where t_id = :new.blue_t;
	end if;
end;
/

create or replace trigger DisjointPlayer
before insert on Player
for each row
declare
	num number;
begin
	select count(*) into num from Coach where id = :new.id;

	if num > 0 then
		raise_application_error(-20999, 'A coach cant be a player.');
	end if;
end;
/

create or replace trigger DisjointCoach
before insert on Coach
for each row
declare
	num number;
begin
	select count(*) into num from Player where id = :new.id;

	if num > 0 then
		raise_application_error(-20999, 'A player cant be a coach.');
	end if;
end;
/

create or replace trigger InsertWeekMVP
before insert on Week
for each row
begin
	if :new.week_mvp is not null then
		raise_application_error(-20999, 'New weeks cant be inserted with an MVP.');
	end if;
end;
/

create or replace trigger UpdateWeekMVP
before update of week_mvp on Week
for each row
declare
	pteam number;
	pcontinent varchar(13);
	pgames number;
	wgames number;
begin
	select t_id into pteam from Player where id = :new.week_mvp;

	if pteam is null then
		raise_application_error(-20999, 'The week MVP has to have a team.');
	end if;

	select continent into pcontinent from Player natural inner join Team where id = :new.week_mvp;
	select count(*) into pgames from Plays natural inner join Game where id = :new.week_mvp and w_number = :old.w_number and g_duration > 0;
	select count(*) into wgames from Game where w_number = :old.w_number and continent = :old.continent and g_duration > 0;

	if pcontinent not like :old.continent then
		raise_application_error(-20999, 'The week MVPs team has to be from the same region as the game itself.');
	end if;

	if pgames = 0 then
		raise_application_error(-20999, 'The week MVP has to have at least one game in the week.');
	end if;

	if wgames < 10 then
		raise_application_error(-20999, 'Weeks have to be finished before inserting the MVP.');
	end if;
end;
/

create or replace trigger PlayerInTeam
before insert on Plays
for each row
declare
	pteam number;
	pgames number;
	n_tplayers number;
	bteam number;
	rteam number;
begin
	select t_id into pteam from Player where id = :new.id;

	if pteam is null then
		raise_application_error(-20999, 'The player has to have a team.');
	end if;

	select count(*) into pgames from Plays where id = :new.id and code = :new.code;

	if pgames > 0 then
		raise_application_error(-20999, 'The player cant play twice in the same game.');
	end if;

	select count(*) into n_tplayers from Player natural inner join Plays where code = :new.code and t_id = pteam;

	if n_tplayers > 4 then
		raise_application_error(-20999, 'Only five players from the same team can play in the same game.');
	end if;

	select blue_t into bteam from Game where code = :new.code;
	select red_t into rteam from Game where code = :new.code;

	if pteam <> bteam and pteam <> rteam then
		raise_application_error(-20999, 'The player has to belong to either the blue or the red team.');
	end if;
end;
/

create or replace trigger DisabledChampion
before insert on Plays
for each row
declare
	vnum number(2, 1);
	disabled varchar(35);
begin
	select version into vnum from Game g inner join Week w on g.w_number = w.w_number and g.continent = w.continent where g.code = :new.code;
	select count(*) into disabled from Disables where c_id = :new.c_id and version = vnum;

	if disabled > 0 then
		raise_application_error(-20999, 'Players cant play a disbaled champion in the current week.');
	end if;
end;
/

create or replace trigger DeletePerson
before delete on Person
for each row
begin
	delete from Player
	where id = :old.id;

	delete from Coach
	where id = :old.id;
end;
/

insert into Person values(101, 'Balls', 'An Le', 'USA');
insert into Person values(102, 'Meteos', 'William Hartman', 'USA');
insert into Person values(103, 'Incarnati0n', 'Nicolaj Jensen', 'Denmark');
insert into Person values(104, 'Sneaky', 'Zachary Scuderi', 'USA');
insert into Person values(105, 'LemonNation', 'Daerek Hart', 'USA');
insert into Person values(106, 'ZionSpartan', 'Darshan Upadhyaya', 'Canada');
insert into Person values(107, 'Xmithie', 'Jake Puchero', 'Philippines');
insert into Person values(108, 'Pobelter', 'Eugene Park', 'USA');
insert into Person values(109, 'Doublelift', 'Yiliang Peng', 'USA');
insert into Person values(110, 'Aphromoo', 'Zaqueri Black', 'USA');
insert into Person values(111, 'Flaresz', 'Cuong Ta', 'USA');
insert into Person values(112, 'Trashy', 'Jonas Andersen', 'Denmark');
insert into Person values(113, 'Innox', 'Tyson Kapler', 'Canada');
insert into Person values(114, 'Otter', 'Brian Baniqued', 'USA');
insert into Person values(115, 'Bodydrop', 'Adam Krauthaker', 'Canada');
insert into Person values(116, 'Hauntzer', 'Kevin Yarnell', 'USA');
insert into Person values(117, 'Move', 'Kang Min-su', 'South Korea');
insert into Person values(118, 'Keane', 'Lae-Young Jang', 'South Korea');
insert into Person values(119, 'Altec', 'Johnny Ru', 'Canada');
insert into Person values(120, 'Bunny FuFuu', 'Michael Kurylo', 'USA');
insert into Person values(121, 'CaliTrlolz', 'Steven Kim', 'South Korea');
insert into Person values(122, 'Porpoise', 'Braeden Schwark', 'Canada');
insert into Person values(123, 'Slooshi', 'Andrew Pham', 'USA');
insert into Person values(124, 'maplestreet', 'Ainslie Wyllie', 'Canada');
insert into Person values(125, 'Dodo', 'Jun Kang', 'South Korea');
insert into Person values(126, 'Gamsu', 'Yeong-jin Noh', 'South Korea');
insert into Person values(127, 'Azingy', 'Andrew Zamarripa', 'USA');
insert into Person values(128, 'Shiphtur', 'Danny Le', 'Canada');
insert into Person values(129, 'CoreJJ', 'Yong-in Jo', 'South Korea');
insert into Person values(130, 'KiWiKiD', 'Alan Nguyen', 'USA');
insert into Person values(131, 'Seraph', 'Shin Woo-Yeong', 'South Korea');
insert into Person values(132, 'Kez', 'Kevin Jeon', 'USA');
insert into Person values(133, 'Ninja', 'Noh Geon-woo', 'South Korea');
insert into Person values(134, 'Emperor', 'Kim Jin-hyun', 'South Korea');
insert into Person values(135, 'Smoothie', 'Andy Ta', 'Canada');
insert into Person values(136, 'Impact', 'Eon-Young Jeong', 'South Korea');
insert into Person values(137, 'Rush', 'Yoonjae Lee', 'South Korea');
insert into Person values(138, 'XiaoWeiXiao', 'Xian Yu', 'China');
insert into Person values(139, 'Apollo', 'Apollo Price', 'USA');
insert into Person values(140, 'Adrian', 'Adrian Ma', 'USA');
insert into Person values(141, 'Quas', 'Diego Ruiz', 'Venezuela');
insert into Person values(142, 'IWDominate', 'Christian Rivera', 'USA');
insert into Person values(143, 'FeniX', 'Jae-hoon Kim', 'South Korea');
insert into Person values(144, 'Piglet', 'Gwang-jin Chae', 'South Korea');
insert into Person values(145, 'Xpecial', 'Alex Chu', 'USA');
insert into Person values(146, 'Dyrus', 'Marcus Hill', 'USA');
insert into Person values(147, 'Santorin', 'Lucas Larsen', 'Denmark');
insert into Person values(148, 'Bjergsen', 'Soren Bjerg', 'Denmark');
insert into Person values(149, 'WildTurtle', 'Jason Tran', 'Canada');
insert into Person values(150, 'Lustboy', 'Jang-sik Ham', 'South Korea');
insert into Person values(151, 'YoungBuck', 'Joey Steltenpool', 'Netherlands');
insert into Person values(152, 'Airwaks', 'Karim Benghalia', 'Switzerland');
insert into Person values(153, 'Soren', 'Soren Frederiksen', 'Denmark');
insert into Person values(154, 'Freeze', 'Ales Knezinek', 'Czech Republic');
insert into Person values(155, 'Unlimited', 'Petar Georgiev', 'Bulgaria');
insert into Person values(156, 'Jwaow', 'Jesper Strandgren', 'Sweden');
insert into Person values(157, 'Dexter', 'Marcel Feldkamp', 'Germany');
insert into Person values(158, 'Froggen', 'Henrik Hansen', 'Denmark');
insert into Person values(159, 'Tabzz', 'Erik Van Helvert', 'Netherlands');
insert into Person values(160, 'promisQ', 'Hampus Abrahamsson', 'Sweden');
insert into Person values(161, 'Huni', 'Seung-Hoon Heo', 'South Korea');
insert into Person values(162, 'Reignover', 'Yeu Jin Kim', 'South Korea');
insert into Person values(163, 'Febiven', 'Fabian Diepstraten', 'Netherlands');
insert into Person values(164, 'Rekkles', 'Martin Larsson', 'Sweden');
insert into Person values(165, 'YellOwStaR', 'Bora Kim', 'France');
insert into Person values(166, 'Cabochard', 'Lucas Simon-Meslet', 'France');
insert into Person values(167, 'Diamondprox', 'Danil Reshetnikov', 'Russia');
insert into Person values(168, 'Betsy', 'Felix Edling', 'Sweden');
insert into Person values(169, 'FORG1VEN', 'Konstantinos Tzortziou-Napoleon', 'Greece');
insert into Person values(170, 'Gosu Pepper', 'Eduard Abgaryan', 'Armenia');
insert into Person values(171, 'Werlyb', 'Jorge Casanovas Moreno-Torres', 'Spain');
insert into Person values(172, 'Fr3deric', 'Federic Lizondo Mata', 'Spain');
insert into Person values(173, 'PepiiNeRO', 'Isaac Flores Alvarado', 'Spain');
insert into Person values(174, 'Adryh', 'Adrian Perez Gonzalez', 'Spain');
insert into Person values(175, 'Rydle', 'Fernando Soria Garcia', 'Spain');
insert into Person values(176, 'Odoamne', 'Andrei Pascu', 'Romania');
insert into Person values(177, 'Loulex', 'Jean Burgevin', 'France');
insert into Person values(178, 'Ryu', 'Sangwook Yoo', 'South Korea');
insert into Person values(179, 'Hjarnan', 'Petter Freyschuss', 'Sweden');
insert into Person values(180, 'kaSing', 'Raymond Tsang', 'United Kingdom');
insert into Person values(181, 'SoaZ', 'Paul Boyer', 'France');
insert into Person values(182, 'Amazing', 'Maurice Stuckenschneider', 'Germany');
insert into Person values(183, 'xPeke', 'Enrique Cedeno Martinez', 'Spain');
insert into Person values(184, 'Niels', 'Jesper Svenningsen', 'Denmark');
insert into Person values(185, 'Mithy', 'Alfonso Aguirre Rodriguez', 'Spain');
insert into Person values(186, 'fredy122', 'Simon Payne', 'United Kingdom');
insert into Person values(187, 'Svenskeren', 'Dennis Johnsen', 'Denmark');
insert into Person values(188, 'Fox', 'Hampus Myhre', 'Sweden');
insert into Person values(189, 'CandyPanda', 'Adrian Wubbelmann', 'Germany');
insert into Person values(190, 'nRated', 'Christoph Seitz', 'Germany');
insert into Person values(191, 'Steve', 'Etienne Michels', 'France');
insert into Person values(192, 'Jankos', 'Marcin Jankowski', 'Poland');
insert into Person values(193, 'Nukeduck', 'Erlend Holm', 'Norway');
insert into Person values(194, 'Woolite', 'Pawel Pruski', 'Poland');
insert into Person values(195, 'VandeR', 'Oskar Bogdan', 'Poland');
insert into Person values(196, 'Vizicsacsi', 'Tamas Kiss', 'Hungary');
insert into Person values(197, 'Kikis', 'Mateusz Szkudlarek', 'Poland');
insert into Person values(198, 'PowerOfEvil', 'Tristan Schrage', 'Germany');
insert into Person values(199, 'Vardags', 'Pontus Dahlblom', 'Sweden');
insert into Person values(200, 'Hylissang', 'Zdravets Galabov', 'Bulgaria');
insert into Person values(201, 'Charlie', 'Charlie Lipsie', 'China');
insert into Person values(202, 'Hai', 'Hai Lam', 'USA');
insert into Person values(203, 'HuHi', 'Choi Jae-hyun', 'South Korea');
insert into Person values(204, 'Lazydude', 'Brad Marx', 'USA');
insert into Person values(205, 'LS', 'Nick De Cesare', 'USA');
insert into Person values(206, 'Matthew Schmieder', 'Matthew Schmieder', 'USA');
insert into Person values(207, 'Rico', 'Rico', 'USA');
insert into Person values(208, 'chain', 'Kim Dong-woo', 'South Korea');
insert into Person values(209, 'Fly', 'Sangchul Kim', 'South Korea');
insert into Person values(210, 'Peter', 'Peter Zhang', 'China');
insert into Person values(211, 'Locodoco', 'Choi Yoon-sub', 'South Korea');
insert into Person values(212, 'Dentist', 'Karl Krey', 'Germany');
insert into Person values(213, 'Nyph', 'Patrick Funke', 'Germany');
insert into Person values(214, 'Deilor', 'Louis Sevilla', 'Spain');
insert into Person values(215, 'LoZarK', 'Julen Lopetegui', 'Spain');
insert into Person values(216, 'Pr0lly', 'Neil Hammad', 'USA');
insert into Person values(217, 'Ducky', 'Titus Hafner', 'Germany');
insert into Person values(218, 'YamatoCannon', 'Jakob Mebdi', 'Sweden');
insert into Person values(219, 'Sheepy', 'Fabian Mallant', 'Germany');
insert into Person values(220, 'Nien', 'Zach Malhas', 'USA');

insert into Region values('North America');
insert into Region values('Europe');

insert into Team values(11, 'C9', 'Cloud9', 0, 0, to_date('2012.12.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(12, 'CLG', 'Counter Logic Gaming', 0, 0, to_date('2010.04.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(13, 'NME', 'Enemy Esports', 0, 0, to_date('2014.11.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(14, 'GV', 'Gravity', 0, 0, to_date('2015.01.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(15, 'T8', 'Team 8', 0, 0, to_date('2013.12.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(16, 'Dig', 'Team Dignitas', 0, 0, to_date('2011.09.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(17, 'TDK', 'Team Dragon Knights', 0, 0, to_date('2014.09.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(18, 'TiP', 'Team Impulse', 0, 0, to_date('2015.01.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(19, 'TL', 'Team Liquid', 0, 0, to_date('2015.01.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(20, 'TSM', 'Team SoloMid', 0, 0, to_date('2011.01.01', 'YYYY.MM.DD'), 'North America');
insert into Team values(21, 'CW', 'Copenhagen Wolves', 0, 0, to_date('2012.08.01', 'YYYY.MM.DD'), 'Europe');
insert into Team values(22, 'EL', 'Elements', 0, 0, to_date('2015.01.01', 'YYYY.MM.DD'), 'Europe');
insert into Team values(23, 'FNC', 'Fnatic', 0, 0, to_date('2011.03.01', 'YYYY.MM.DD'), 'Europe');
insert into Team values(24, 'GMB', 'Gambit Gaming', 0, 0, to_date('2013.01.01', 'YYYY.MM.DD'), 'Europe');
insert into Team values(25, 'GIA', 'GIANTS GAMING', 0, 0, to_date('2012.08.01', 'YYYY.MM.DD'), 'Europe');
insert into Team values(26, 'H2K', 'H2K', 0, 0, to_date('2013.12.01', 'YYYY.MM.DD'), 'Europe');
insert into Team values(27, 'OG', 'ORIGEN', 0, 0, to_date('2015.01.01', 'YYYY.MM.DD'), 'Europe');
insert into Team values(28, 'SK', 'SK Gaming', 0, 0, to_date('2010.09.01', 'YYYY.MM.DD'), 'Europe');
insert into Team values(29, 'ROC', 'Team ROCCAT', 0, 0, to_date('2012.09.01', 'YYYY.MM.DD'), 'Europe');
insert into Team values(30, 'UoL', 'Unicorns of Love', 0, 0, to_date('2013.08.01', 'YYYY.MM.DD'), 'Europe');

insert into Player values(101, 'Top', to_date('1994.06.22', 'YYYY.MM.DD'), 11);
insert into Player values(102, 'Jungler', to_date('1993.01.01', 'YYYY.MM.DD'), 11);
insert into Player values(103, 'Mid', to_date('1993.02.02', 'YYYY.MM.DD'), 11);
insert into Player values(104, 'AD Carry', to_date('1994.03.19', 'YYYY.MM.DD'), 11);
insert into Player values(105, 'Support', to_date('1989.06.15', 'YYYY.MM.DD'), 11);
insert into Player values(106, 'Top', to_date('1994.11.12', 'YYYY.MM.DD'), 12);
insert into Player values(107, 'Jungler', to_date('1991.05.10', 'YYYY.MM.DD'), 12);
insert into Player values(108, 'Mid', to_date('1995.10.14', 'YYYY.MM.DD'), 12);
insert into Player values(109, 'AD Carry', to_date('1993.07.19', 'YYYY.MM.DD'), 12);
insert into Player values(110, 'Support', to_date('1992.09.08', 'YYYY.MM.DD'), 12);
insert into Player values(111, 'Top', to_date('1993.03.03', 'YYYY.MM.DD'), 13);
insert into Player values(112, 'Jungler', to_date('1993.04.04', 'YYYY.MM.DD'), 13);
insert into Player values(113, 'Mid', to_date('1995.07.05', 'YYYY.MM.DD'), 13);
insert into Player values(114, 'AD Carry', to_date('1993.05.05', 'YYYY.MM.DD'), 13);
insert into Player values(115, 'Support', to_date('1993.06.06', 'YYYY.MM.DD'), 13);
insert into Player values(116, 'Top', to_date('1995.05.20', 'YYYY.MM.DD'), 14);
insert into Player values(117, 'Jungler', to_date('1992.05.23', 'YYYY.MM.DD'), 14);
insert into Player values(118, 'Mid', to_date('1993.07.07', 'YYYY.MM.DD'), 14);
insert into Player values(119, 'AD Carry', to_date('1997.05.08', 'YYYY.MM.DD'), 14);
insert into Player values(120, 'Support', to_date('1993.08.08', 'YYYY.MM.DD'), 14);
insert into Player values(121, 'Top', to_date('1993.09.09', 'YYYY.MM.DD'), 15);
insert into Player values(122, 'Jungler', to_date('1993.10.10', 'YYYY.MM.DD'), 15);
insert into Player values(123, 'Mid', to_date('1993.11.11', 'YYYY.MM.DD'), 15);
insert into Player values(124, 'AD Carry', to_date('1993.01.10', 'YYYY.MM.DD'), 15);
insert into Player values(125, 'Support', to_date('1993.12.12', 'YYYY.MM.DD'), 15);
insert into Player values(126, 'Top', to_date('1994.01.01', 'YYYY.MM.DD'), 16);
insert into Player values(127, 'Jungler', to_date('1994.02.02', 'YYYY.MM.DD'), 16);
insert into Player values(128, 'Mid', to_date('1994.03.03', 'YYYY.MM.DD'), 16);
insert into Player values(129, 'AD Carry', to_date('1994.06.22', 'YYYY.MM.DD'), 16);
insert into Player values(130, 'Support', to_date('1993.11.08', 'YYYY.MM.DD'), 16);
insert into Player values(131, 'Top', to_date('1994.04.04', 'YYYY.MM.DD'), 17);
insert into Player values(132, 'Jungler', to_date('1994.05.05', 'YYYY.MM.DD'), 17);
insert into Player values(133, 'Mid', to_date('1994.06.06', 'YYYY.MM.DD'), 17);
insert into Player values(134, 'AD Carry', to_date('1993.06.07', 'YYYY.MM.DD'), 17);
insert into Player values(135, 'Support', to_date('1997.02.10', 'YYYY.MM.DD'), 17);
insert into Player values(136, 'Top', to_date('1995.03.07', 'YYYY.MM.DD'), 18);
insert into Player values(137, 'Jungler', to_date('1994.07.07', 'YYYY.MM.DD'), 18);
insert into Player values(138, 'Mid', to_date('1994.09.15', 'YYYY.MM.DD'), 18);
insert into Player values(139, 'AD Carry', to_date('1994.08.08', 'YYYY.MM.DD'), 18);
insert into Player values(140, 'Support', to_date('1994.09.09', 'YYYY.MM.DD'), 18);
insert into Player values(141, 'Top', to_date('1994.10.10', 'YYYY.MM.DD'), 19);
insert into Player values(142, 'Jungler', to_date('1990.08.13', 'YYYY.MM.DD'), 19);
insert into Player values(143, 'Mid', to_date('1994.11.11', 'YYYY.MM.DD'), 19);
insert into Player values(144, 'AD Carry', to_date('1994.02.04', 'YYYY.MM.DD'), 19);
insert into Player values(145, 'Support', to_date('1992.08.12', 'YYYY.MM.DD'), 19);
insert into Player values(146, 'Top', to_date('1992.03.30', 'YYYY.MM.DD'), 20);
insert into Player values(147, 'Jungler', to_date('1997.05.06', 'YYYY.MM.DD'), 20);
insert into Player values(148, 'Mid', to_date('1996.02.21', 'YYYY.MM.DD'), 20);
insert into Player values(149, 'AD Carry', to_date('1995.02.09', 'YYYY.MM.DD'), 20);
insert into Player values(150, 'Support', to_date('1994.02.18', 'YYYY.MM.DD'), 20);
insert into Player values(151, 'Top', to_date('1991.07.28', 'YYYY.MM.DD'), 21);
insert into Player values(152, 'Jungler', to_date('1994.09.01', 'YYYY.MM.DD'), 21);
insert into Player values(153, 'Mid', to_date('1995.03.29', 'YYYY.MM.DD'), 21);
insert into Player values(154, 'AD Carry', to_date('1994.07.06', 'YYYY.MM.DD'), 21);
insert into Player values(155, 'Support', to_date('1990.06.09', 'YYYY.MM.DD'), 21);
insert into Player values(156, 'Top', to_date('1994.12.12', 'YYYY.MM.DD'), 22);
insert into Player values(157, 'Jungler', to_date('1992.01.01', 'YYYY.MM.DD'), 22);
insert into Player values(158, 'Mid', to_date('1994.02.21', 'YYYY.MM.DD'), 22);
insert into Player values(159, 'AD Carry', to_date('1994.03.17', 'YYYY.MM.DD'), 22);
insert into Player values(160, 'Support', to_date('1992.02.02', 'YYYY.MM.DD'), 22);
insert into Player values(161, 'Top', to_date('1997.12.25', 'YYYY.MM.DD'), 23);
insert into Player values(162, 'Jungler', to_date('1992.03.03', 'YYYY.MM.DD'), 23);
insert into Player values(163, 'Mid', to_date('1992.04.04', 'YYYY.MM.DD'), 23);
insert into Player values(164, 'AD Carry', to_date('1996.09.20', 'YYYY.MM.DD'), 23);
insert into Player values(165, 'Support', to_date('1992.02.15', 'YYYY.MM.DD'), 23);
insert into Player values(166, 'Top', to_date('1992.05.05', 'YYYY.MM.DD'), 24);
insert into Player values(167, 'Jungler', to_date('1992.12.24', 'YYYY.MM.DD'), 24);
insert into Player values(168, 'Mid', to_date('1992.06.06', 'YYYY.MM.DD'), 24);
insert into Player values(169, 'AD Carry', to_date('1992.06.23', 'YYYY.MM.DD'), 24);
insert into Player values(170, 'Support', to_date('1994.05.01', 'YYYY.MM.DD'), 24);
insert into Player values(171, 'Top', to_date('1997.08.14', 'YYYY.MM.DD'), 25);
insert into Player values(172, 'Jungler', to_date('1994.05.29', 'YYYY.MM.DD'), 25);
insert into Player values(173, 'Mid', to_date('1994.10.18', 'YYYY.MM.DD'), 25);
insert into Player values(174, 'AD Carry', to_date('1996.07.31', 'YYYY.MM.DD'), 25);
insert into Player values(175, 'Support', to_date('1992.06.02', 'YYYY.MM.DD'), 25);
insert into Player values(176, 'Top', to_date('1992.07.07', 'YYYY.MM.DD'), 26);
insert into Player values(177, 'Jungler', to_date('1995.03.27', 'YYYY.MM.DD'), 26);
insert into Player values(178, 'Mid', to_date('1994.01.28', 'YYYY.MM.DD'), 26);
insert into Player values(179, 'AD Carry', to_date('1992.08.08', 'YYYY.MM.DD'), 26);
insert into Player values(180, 'Support', to_date('1993.12.08', 'YYYY.MM.DD'), 26);
insert into Player values(181, 'Top', to_date('1994.01.09', 'YYYY.MM.DD'), 27);
insert into Player values(182, 'Jungler', to_date('1994.04.02', 'YYYY.MM.DD'), 27);
insert into Player values(183, 'Mid', to_date('1992.04.24', 'YYYY.MM.DD'), 27);
insert into Player values(184, 'AD Carry', to_date('1997.12.06', 'YYYY.MM.DD'), 27);
insert into Player values(185, 'Support', to_date('1994.10.05', 'YYYY.MM.DD'), 27);
insert into Player values(186, 'Top', to_date('1992.09.09', 'YYYY.MM.DD'), 28);
insert into Player values(187, 'Jungler', to_date('1996.01.02', 'YYYY.MM.DD'), 28);
insert into Player values(188, 'Mid', to_date('1995.05.26', 'YYYY.MM.DD'), 28);
insert into Player values(189, 'AD Carry', to_date('1993.06.23', 'YYYY.MM.DD'), 28);
insert into Player values(190, 'Support', to_date('1991.07.17', 'YYYY.MM.DD'), 28);
insert into Player values(191, 'Top', to_date('1995.07.09', 'YYYY.MM.DD'), 29);
insert into Player values(192, 'Jungler', to_date('1992.10.10', 'YYYY.MM.DD'), 29);
insert into Player values(193, 'Mid', to_date('1992.11.11', 'YYYY.MM.DD'), 29);
insert into Player values(194, 'AD Carry', to_date('1992.12.12', 'YYYY.MM.DD'), 29);
insert into Player values(195, 'Support', to_date('1995.04.18', 'YYYY.MM.DD'), 29);
insert into Player values(196, 'Top', to_date('1993.06.14', 'YYYY.MM.DD'), 30);
insert into Player values(197, 'Jungler', to_date('1996.03.16', 'YYYY.MM.DD'), 30);
insert into Player values(198, 'Mid', to_date('1991.12.12', 'YYYY.MM.DD'), 30);
insert into Player values(199, 'AD Carry', to_date('1991.11.11', 'YYYY.MM.DD'), 30);
insert into Player values(200, 'Support', to_date('1995.01.01', 'YYYY.MM.DD'), 30);
insert into Player values(203, 'Mid', to_date('1995.02.02', 'YYYY.MM.DD'), 12);
insert into Player values(220, 'AD Carry', to_date('1994.07.01', 'YYYY.MM.DD'), 15);

insert into Coach values(201, 'Coach', 11);
insert into Coach values(202, 'Analyst', 11);
insert into Coach values(204, 'Coach', 13);
insert into Coach values(205, 'Coach', 14);
insert into Coach values(206, 'Analyst', 15);
insert into Coach values(207, 'Analyst', 16);
insert into Coach values(208, 'Coach', 17);
insert into Coach values(209, 'Coach', 18);
insert into Coach values(210, 'Coach', 19);
insert into Coach values(211, 'Coach', 20);
insert into Coach values(212, 'Coach', 21);
insert into Coach values(213, 'Coach', 22);
insert into Coach values(214, 'Coach', 23);
insert into Coach values(215, 'Analyst', 25);
insert into Coach values(216, 'Coach', 26);
insert into Coach values(217, 'Coach', 27);
insert into Coach values(218, 'Coach', 29);
insert into Coach values(219, 'Coach', 30);

insert into Brand values(11, 'Alienware');
insert into Brand values(12, 'AMD');
insert into Brand values(13, 'ASRock');
insert into Brand values(14, 'Azubu');
insert into Brand values(15, 'Cooler Master');
insert into Brand values(16, 'Corsair');
insert into Brand values(17, 'Eizo');
insert into Brand values(18, 'HTC');
insert into Brand values(19, 'iBUYPOWER');
insert into Brand values(20, 'Intel');
insert into Brand values(21, 'Kingston HyperX');
insert into Brand values(22, 'Logitech');
insert into Brand values(23, 'Nissan');
insert into Brand values(24, 'Nvidia');
insert into Brand values(25, 'Ozone');
insert into Brand values(26, 'Pringles');
insert into Brand values(27, 'Razer');
insert into Brand values(28, 'ROCCAT');
insert into Brand values(29, 'SanDisk');
insert into Brand values(30, 'SteelSeries');

insert into Champion values(101, 'Ahri', 'Mage');
insert into Champion values(102, 'Akali', 'Assassin');
insert into Champion values(103, 'Alistar', 'Tank');
insert into Champion values(104, 'Annie', 'Mage');
insert into Champion values(105, 'Caitlyn', 'Marksman');
insert into Champion values(106, 'Draven', 'Marksman');
insert into Champion values(107, 'Elise', 'Mage');
insert into Champion values(108, 'Evelynn', 'Assassin');
insert into Champion values(109, 'Ezreal', 'Marksman');
insert into Champion values(110, 'Graves', 'Marksman');
insert into Champion values(111, 'Irelia', 'Fighter');
insert into Champion values(112, 'Jarvan IV', 'Tank');
insert into Champion values(113, 'Jax', 'Fighter');
insert into Champion values(114, 'Jinx', 'Marksman');
insert into Champion values(115, 'Kayle', 'Fighter');
insert into Champion values(116, 'Kennen', 'Mage');
insert into Champion values(117, 'Lissandra', 'Mage');
insert into Champion values(118, 'Lucian', 'Marksman');
insert into Champion values(119, 'Lulu', 'Support');
insert into Champion values(120, 'Malphite', 'Tank');
insert into Champion values(121, 'Nidalee', 'Assassin');
insert into Champion values(122, 'Renekton', 'Fighter');
insert into Champion values(123, 'Rengar', 'Assassin');
insert into Champion values(124, 'Riven', 'Fighter');
insert into Champion values(125, 'Shen', 'Tank');
insert into Champion values(126, 'Shyvana', 'Fighter');
insert into Champion values(127, 'Thresh', 'Support');
insert into Champion values(128, 'Tristana', 'Marksman');
insert into Champion values(129, 'Trundle', 'Fighter');
insert into Champion values(130, 'Tryndamere', 'Fighter');
insert into Champion values(131, 'Varus', 'Marksman');
insert into Champion values(132, 'Vayne', 'Marksman');
insert into Champion values(133, 'Yasuo', 'Fighter');
insert into Champion values(134, 'Zed', 'Assassin');

insert into Patch values(5.4);
insert into Patch values(5.5);
insert into Patch values(5.6);
insert into Patch values(5.7);
insert into Patch values(5.8);
insert into Patch values(5.9);

insert into Week values(1, 'North America', 5.4, '');
insert into Week values(2, 'North America', 5.4, '');
insert into Week values(3, 'North America', 5.5, '');
insert into Week values(4, 'North America', 5.5, '');
insert into Week values(5, 'North America', 5.6, '');
insert into Week values(6, 'North America', 5.6, '');
insert into Week values(7, 'North America', 5.7, '');
insert into Week values(8, 'North America', 5.8, '');
insert into Week values(9, 'North America', 5.9, '');
insert into Week values(1, 'Europe', 5.4, '');
insert into Week values(2, 'Europe', 5.4, '');
insert into Week values(3, 'Europe', 5.5, '');
insert into Week values(4, 'Europe', 5.5, '');
insert into Week values(5, 'Europe', 5.6, '');
insert into Week values(6, 'Europe', 5.6, '');
insert into Week values(7, 'Europe', 5.7, '');
insert into Week values(8, 'Europe', 5.8, '');
insert into Week values(9, 'Europe', 5.9, '');

insert into Day values(1, 1, 'North America');
insert into Day values(2, 1, 'North America');
insert into Day values(1, 2, 'North America');
insert into Day values(2, 2, 'North America');
insert into Day values(1, 3, 'North America');
insert into Day values(2, 3, 'North America');
insert into Day values(1, 4, 'North America');
insert into Day values(2, 4, 'North America');
insert into Day values(1, 5, 'North America');
insert into Day values(2, 5, 'North America');
insert into Day values(1, 6, 'North America');
insert into Day values(2, 6, 'North America');
insert into Day values(1, 7, 'North America');
insert into Day values(2, 7, 'North America');
insert into Day values(1, 8, 'North America');
insert into Day values(2, 8, 'North America');
insert into Day values(1, 9, 'North America');
insert into Day values(2, 9, 'North America');
insert into Day values(1, 1, 'Europe');
insert into Day values(2, 1, 'Europe');
insert into Day values(1, 2, 'Europe');
insert into Day values(2, 2, 'Europe');
insert into Day values(1, 3, 'Europe');
insert into Day values(2, 3, 'Europe');
insert into Day values(1, 4, 'Europe');
insert into Day values(2, 4, 'Europe');
insert into Day values(1, 5, 'Europe');
insert into Day values(2, 5, 'Europe');
insert into Day values(1, 6, 'Europe');
insert into Day values(2, 6, 'Europe');
insert into Day values(1, 7, 'Europe');
insert into Day values(2, 7, 'Europe');
insert into Day values(1, 8, 'Europe');
insert into Day values(2, 8, 'Europe');
insert into Day values(1, 9, 'Europe');
insert into Day values(2, 9, 'Europe');

insert into Game values(151, to_date('01.01.2015.13.00', 'DD.MM.YYYY.HH24.MI'), 45, 1, 1, 'Europe', 22, 23, 23);
insert into Game values(152, to_date('01.01.2015.14.30', 'DD.MM.YYYY.HH24.MI'), 38, 1, 1, 'Europe', 26, 30, 26);
insert into Game values(153, to_date('01.01.2015.16.00', 'DD.MM.YYYY.HH24.MI'), 31, 1, 1, 'Europe', 27, 29, 27);
insert into Game values(101, to_date('03.01.2015.17.00', 'DD.MM.YYYY.HH24.MI'), 27, 1, 1, 'North America', 11, 12, 11);
insert into Game values(102, to_date('03.01.2015.18.30', 'DD.MM.YYYY.HH24.MI'), 34, 1, 1, 'North America', 13, 14, 14);
insert into Game values(103, to_date('03.01.2015.20.00', 'DD.MM.YYYY.HH24.MI'), 41, 1, 1, 'North America', 15, 16, 16);
insert into Game values(104, to_date('03.01.2015.21.30', 'DD.MM.YYYY.HH24.MI'), 48, 1, 1, 'North America', 17, 18, 18);
insert into Game values(105, to_date('03.01.2015.23.00', 'DD.MM.YYYY.HH24.MI'), 55, 1, 1, 'North America', 19, 20, 20);
insert into Game values(106, to_date('04.01.2015.17.00', 'DD.MM.YYYY.HH24.MI'), 35, 2, 1, 'North America', 11, 20, 11);
insert into Game values(107, to_date('04.01.2015.18.30', 'DD.MM.YYYY.HH24.MI'), 28, 2, 1, 'North America', 12, 19, 19);

insert into Sponsors values(11, 11);
insert into Sponsors values(11, 16);
insert into Sponsors values(11, 19);
insert into Sponsors values(12, 29);
insert into Sponsors values(13, 28);
insert into Sponsors values(14, 23);
insert into Sponsors values(14, 26);
insert into Sponsors values(14, 30);
insert into Sponsors values(15, 21);
insert into Sponsors values(16, 15);
insert into Sponsors values(16, 26);
insert into Sponsors values(17, 23);
insert into Sponsors values(18, 11);
insert into Sponsors values(18, 19);
insert into Sponsors values(18, 20);
insert into Sponsors values(19, 12);
insert into Sponsors values(19, 20);
insert into Sponsors values(20, 16);
insert into Sponsors values(20, 28);
insert into Sponsors values(21, 11);
insert into Sponsors values(21, 16);
insert into Sponsors values(21, 19);
insert into Sponsors values(21, 20);
insert into Sponsors values(21, 28);
insert into Sponsors values(22, 11);
insert into Sponsors values(22, 20);
insert into Sponsors values(23, 19);
insert into Sponsors values(24, 11);
insert into Sponsors values(25, 25);
insert into Sponsors values(25, 27);
insert into Sponsors values(26, 24);
insert into Sponsors values(27, 12);
insert into Sponsors values(27, 19);
insert into Sponsors values(27, 30);
insert into Sponsors values(28, 29);
insert into Sponsors values(29, 12);
insert into Sponsors values(30, 21);
insert into Sponsors values(30, 23);

insert into Disables values(5.4, 121);
insert into Disables values(5.5, 133);
insert into Disables values(5.5, 134);
insert into Disables values(5.7, 111);
insert into Disables values(5.7, 112);
insert into Disables values(5.7, 113);
insert into Disables values(5.9, 114);

insert into Plays values(101, 101, 3, 2, 11, 220, 16142, 111);
insert into Plays values(102, 101, 6, 0, 16, 174, 17126, 107);
insert into Plays values(103, 101, 4, 4, 8, 249, 16996, 134);
insert into Plays values(104, 101, 10, 1, 6, 282, 19328, 118);
insert into Plays values(105, 101, 1, 3, 19, 31, 13564, 127);
insert into Plays values(106, 101, 3, 4, 3, 207, 15762, 117);
insert into Plays values(107, 101, 2, 5, 4, 126, 14843, 112);
insert into Plays values(108, 101, 1, 6, 2, 193, 15572, 133);
insert into Plays values(161, 151, 6, 1, 10, 231, 17642, 126);
insert into Plays values(162, 151, 3, 2, 13, 158, 15651, 123);
insert into Plays values(163, 151, 7, 0, 9, 242, 17924, 101);
insert into Plays values(164, 151, 8, 3, 6, 207, 16849, 110);