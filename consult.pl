:-dynamic yes/1, no/1, model_popularity/2.

rule(1, monitor, "Монитор для игр", [1]).
rule(2, monitor, "Монитор для работы с графикой", [2]).
rule(3, monitor, "Монитор для повседневных задач (офисный)", [3]).

rule(4, "Монитор для игр", "ASUS ROG Swift PG259QN", [4, 5, 6]).
rule(5, "Монитор для игр", "Alienware AW2521H", [4, 6, 8]).
rule(6, "Монитор для работы с графикой", "Eizo ColorEdge CG319X", [6, 7, 8]).
rule(7, "Монитор для работы с графикой", "BenQ PD3220U", [6, 7, 10]).
rule(8, "Монитор для повседневных задач (офисный)", "HP EliteDisplay E243", [6, 9, 11]).
rule(9, "Монитор для повседневных задач (офисный)", "Dell P2419H", [9, 11]).

cond(1, "Монитор для игр").
cond(2, "Монитор для работы с графикой").
cond(3, "Монитор для повседневных задач (офисный)").
cond(4, "Частота обновления выше 75 Гц").
cond(5, "Низкое время отклика: < 5 мс").
cond(6, "Разрешение больше чем 1920x1080").
cond(7, "Точная цветопередача, битность матрицы > 8").
cond(8, "Диагональ больше 27 дюймов").
cond(9, "Режим No Blue").
cond(10, "Поддержка HDR").
cond(11, "USB-C разъем").

start :-
    retractall(yes(_)),
    retractall(no(_)),
    
    % Инициализируем информацию о популярности.
    init_model_popularity,
    write('1. Консультация по выбору монитора'), nl,
    write('2. Завершить программу'), nl,
    write('Ваш выбор: '), read(Choice), nl,
    process(Choice).

process(1) :-
    consult_monitor,
    fail.

process(2) :-
    write('Завершение работы'), !.

process(_) :-
    write('Некорректный ответ. Попробуйте снова.'), nl,
    ask_restart.

consult_monitor :-
    write('Введите monitor - начать консультацию ; ? - вывести все доступные варианты: '), read(Goal), nl,
    info(Goal), !,
    go([], Goal).

info('?') :-
    write('Возможные типы мониторов:'), nl,
    forall((rule(N,_,Monitor,_), N >= 4), (write('- '), write(Monitor), nl)),
    ask_restart, fail.

info(monitor).

info(_) :-
    write('Такой темы нет. Попробуйте снова.'), nl,
    ask_restart, fail.

go(Hist, Goal) :-
    % Если Goal — это конечная модель
    \+ rule(_, Goal, _, _),
    format('Подходящая модель: ~w.~n', [Goal]),
    increment_model_popularity(Goal),
    write('Показать объяснение (1 - да / 2 - нет)? '),
    read(R), eval_reply(Hist, R),
    ask_restart.

go(Hist, Goal) :-
    
    % Кладем все факты в Rules.
    findall(rule(RID, Goal, Subgoal, Conds), rule(RID, Goal, Subgoal, Conds), Rules),
    
    % Если нужно сортировать факты по популярности - сортируем.
    (should_sort_rules(Rules) ->
        sort_rules_by_model_popularity(Rules, SortedRules)
    ;
        SortedRules = Rules
    ),
    try_rules(Hist, SortedRules), !.

% Проверяем, нужно ли сортировать правила:
% - Только если все Subgoal — это конечные модели
% - И хотя бы одна из них имеет ненулевую популярность
should_sort_rules(Rules) :-
    forall(member(rule(_, _, Subgoal, _), Rules), is_terminal(Subgoal)),
    member(rule(_, _, Subgoal, _), Rules),
    model_popularity(Subgoal, Pop),
    Pop > 0.

% Проверка: конечная ли цель (т.е. не вид монитора, а конкретная модель).
is_terminal(Goal) :-
    \+ rule(_, Goal, _, _).

% Перебираем список с правилами.
try_rules(_, []) :- 
    write('Не удалось найти подходящие модели на основе ваших ответов.'), nl,
    ask_restart, fail.

try_rules(Hist, [rule(RID, _, Subgoal, Conds)|_]) :-
    check(RID, Hist, Conds),
    go([RID|Hist], Subgoal).

try_rules(Hist, [_|Rest]) :-
    try_rules(Hist, Rest).

% Проверка условий.
check(_, _, []).
check(RuleID, Hist, [Cond|Rest]) :-
    ( yes(Cond) -> true
    ; no(Cond) -> fail
    ; cond(Cond, Text),
      ask(Text, Response),
      handle_response(Response, Cond)
    ),
    check(RuleID, Hist, Rest).

ask(Question, Response) :-
    format('~w? (1 - да, 2 - нет): ', [Question]),
    read(Response).

handle_response(1, Cond) :- !, assertz(yes(Cond)).
handle_response(2, Cond) :- !, assertz(no(Cond)), fail.
handle_response(_, _) :-
    write('Некорректный ответ. Попробуйте снова.'), nl,
    ask_restart, fail.

eval_reply([], _) :- !.
eval_reply(Hist, 1) :- print_rules(Hist), !.
eval_reply(_, _).

print_rules([]).
print_rules([R|Rs]) :-
    rule(R, _, _, CondList),
    print_conditions(CondList),
    print_rules(Rs).

print_conditions([]).
print_conditions([BNO|Rest]) :-
    cond(BNO, Text),
    write('- '), write(Text), nl,
    print_conditions(Rest).

ask_restart :-
    nl, write('Хотите попробовать снова? (1 - да / 2 - нет): '),
    read(Resp),
    (Resp =:= 1 -> start ; write('Завершение работы'), nl).

% При инициализации все ставим в 0.
init_model_popularity :-
    forall((rule(_, _, Model, _), \+ rule(_, Model, _, _)),
        (model_popularity(Model, _) -> true ; assertz(model_popularity(Model, 0)))).

% Увеличиваем счетчик популярности модели монитора.
increment_model_popularity(Model) :-
    model_popularity(Model, Old),
    New is Old + 1,
    retract(model_popularity(Model, Old)),
    assertz(model_popularity(Model, New)).

% Сортирует варианты по убыванию популярности.
sort_rules_by_model_popularity(Rules, Sorted) :-
    map_list_to_pairs(rule_model_popularity, Rules, Pairs),
    keysort(Pairs, SortedPairs),
    reverse(SortedPairs, RevSorted),
    pairs_values(RevSorted, Sorted).

% Определяет популярность модели для правила.
rule_model_popularity(rule(_, _, Model, _), Pop) :-
    (model_popularity(Model, Pop) -> true ; Pop = 0).