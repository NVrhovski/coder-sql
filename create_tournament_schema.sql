create schema tournament_schema;

use tournament_schema;

create table tournament_formats (
	id_format int not null primary key auto_increment,
    format_description varchar(40) not null
);

create table tournaments (
	id_tournament int not null primary key auto_increment,
    tournament_name varchar(40) not null,
    day_from date,
    day_tru date,
    teams_number int not null,
    id_format int not null,
    foreign key (id_format) references tournament_formats(id_format)
);

create table referees (
	dni_referee int not null primary key,
    referee_firstname varchar(20) not null,
    referee_lastname varchar(20) not null
);

create table teams (
	id_team int not null primary key auto_increment,
    team_name varchar (30) not null,
    dni_dt int not null,
    players_count int not null
);

create table dt (
	dni_dt int not null primary key,
    dt_firstname varchar(20) not null,
    dt_lastname varchar(20) not null,
    id_team int not null
);

create table players (
	dni_player int not null primary key,
    player_firstname varchar(20) not null,
    player_lastname varchar(20) not null,
    id_team int not null
);

alter table players
add foreign key (id_team) references teams(id_team);

create table matches (
	id_match int not null primary key auto_increment,
    match_date datetime not null,
    id_tournament int not null,
    id_team int not null,
    dni_referee int not null,
    goals tinyint not null,
    penalties boolean not null,
    res_penalties tinyint,
    foreign key (id_tournament) references tournaments(id_tournament),
    foreign key (id_team) references teams(id_team),
    foreign key (dni_referee) references referees(dni_referee)
);

create view matches_per_team as
select a.id_team, b.team_name, count(*) matches_played
from matches a
left join teams b
on a.id_team = b.id_team
group by id_team
order by matches_played desc;

create view goals_per_team as 
select a.id_team, b.team_name, sum(a.goals) total_goals
from matches a
left join teams b
on a.id_team = b.id_team
group by id_team
order by total_goals desc;

create view matches_per_tournament as 
select a.id_tournament, b.tournament_name, count(*) matches_per_tournament
from matches a 
left join tournaments b
on a.id_tournament = b.id_tournament
group by id_tournament
order by matches_per_tournament desc;

create view matches_per_referee as 
select a.dni_referee, b.referee_firstname, b.referee_lastname, count(*) matches_participated
from matches a 
left join referees b
on a.dni_referee = b.dni_referee
group by dni_referee
order by matches_participated desc;

create view full_matches_report as
select a.id_match, a.match_date, b.tournament_name, c.team_name, d.referee_firstname, d.referee_lastname, a.goals, a.penalties, a.res_penalties from matches a
left join tournaments b
on a.id_tournament = b.id_tournament
left join teams c
on a.id_team = c.id_team
left join referees d
on a.dni_referee = d.dni_referee;

create function quitar_espacios(texto varchar(40)) 
returns varchar(40)
deterministic
return (
	select replace(texto, ' ', '')
);

create function conseguir_nombre_dt(dni int)
returns varchar(80)
reads sql data
return (
	select concat(dt_lastname, ', ', dt_firstname)
    from dt
    where dni_dt = dni
);

delimiter //

create procedure ordenarPartidosPorColumna(in columna varchar(30), in orden varchar(5))
begin
	-- Aca declaro la variable 'queryDinamica' y le asigno el valor de la query que debemos ejecutar, incluyendo los parametros dinamicos de columna y orden
	set @queryDinamica = concat('select * from matches order by ', columna, ' ', orden);
    -- Aca preparo y ejecuto el 'prepared statement' para que me devuelva la respuesta de la query
    prepare stmt3 from @queryDinamica;
    execute stmt3;
    -- Finalmente elimino el statement para que no falle al usar el procedure por segunda vez
    deallocate prepare stmt3;
end// 

create procedure insertarFilaFormatos(descripcion varchar(50))
begin
	-- Aca declaro la variable 'queryDinamica' y le asigno el valor de la query que debemos ejecutar, incluyendo el parametro de la descripcion
	set @queryDinamica = concat("insert into tournament_formats (format_description) values ('", descripcion, "')");
    -- Aca preparo y ejecuto el 'prepared statement' para que me devuelva la respuesta de la query
    prepare stmt3 from @queryDinamica;
    execute stmt3;
    -- Finalmente elimino el statement para que no falle al usar el procedure por segunda vez
    deallocate prepare stmt3;
end//

-- Este trigger sirve para que, si el partido no tuvo penales, el resultado de los penales tenga que ser si o si null
create trigger checkear_insert_matches
before insert on matches
for each row
begin
	if new.penalties = 0 and new.res_penalties is not null then
		signal sqlstate '45000' set message_text = 'Si la columna penalties es false, la columna res_penalties debe ser null';
    end if;
end//

-- Aca creo la tabla en donde voy a guardar los logs de la tabla matches
create table log_matches (
	id_match int not null,
    log_user varchar(40) not null,
    log_date date not null,
    log_time time not null
)//

-- Este trigger sirve guardar en la tabla log_matches los logs de cada insert en la tabla matches
create trigger trigger_reporte_matches
after insert on matches
for each row
begin
	insert into log_matches values
    (new.id_match, user(), current_date(), current_time());
end//

-- Este trigger sirve para evitar que la fecha de inicio de un torneo sea posterior a su fecha de finalizacion
create trigger checkear_insert_tournaments
before insert on tournaments
for each row
begin
	if new.day_from > new.day_tru then
		signal sqlstate '45000' set message_text = 'La columna day_from no puede ser posterior a la columna day_tru';
    end if;
end//

-- Aca creo la tabla en donde voy a guardar los logs de la tabla tournaments
create table log_tournaments (
	id_tournament int not null,
    log_user varchar(40) not null,
    log_date date not null,
    log_time time not null
)//

-- Este trigger sirve guardar en la tabla log_tournaments los logs de cada insert en la tabla tournaments
create trigger trigger_reporte_tournaments
after insert on tournaments
for each row
begin
	insert into log_tournaments values
    (new.id_tournament, user(), current_date(), current_time());
end//

delimiter ;

-- El usuario 'lector' tiene permisos unicamente para usar el comando 'select'
create user 'lector'@'localhost'; 
grant select on *.* to 'lector'@'localhost';

-- El usuario 'admin' tiene permisos para usar los comandos 'select', 'insert' y 'update'
create user 'admin'@'localhost';
grant select, insert, update on *.* to 'admin'@'localhost';

set autocommit = 0;

start transaction;
delete from matches
where id_match > 4;
-- rollback;
commit;

start transaction;
insert into players 
values 
(32324637, 'Gustavo', 'Galindez', 1),
(12363526, 'Henry', 'Martinez', 2),
(65474635, 'Gonzalo', 'Guedes', 3),
(12463527, 'Fernando', 'Cavenaghi', 4);
savepoint primer_lote;
insert into players 
values
(53750987, 'Vito', 'Gregorio', 1),
(43746352, 'Neyen', 'Vrhovski', 2),
(12463546, 'Tomas', 'Fernandez', 3),
(32645635, 'Sebastian', 'Biglia', 4);
savepoint segundo_lote;
-- rollback to primer_lote;
commit;