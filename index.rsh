'reach 0.1';

const DEADLINE = 10;
const [isResult, ERIN_WINS, LOLA_WINS, DRAW] = makeEnum(3);

const roundWinner = (fingersErin, guessErin, fingersLola, guessLola) => {
    const playedFingers = fingersErin + fingersLola;

    if (guessErin == playedFingers) {
        if (guessLola == playedFingers) {
            return DRAW;
        } else {
            return ERIN_WINS;
        }
    } else if (guessErin != playedFingers) {
        if (guessLola != playedFingers){
            return DRAW;
        } else {
            return LOLA_WINS;
        }
    } else {
        return DRAW;
    }
};

const gameWinner = (pointsErin, pointsLola) => {
    if (pointsErin > pointsLola) {
        return ERIN_WINS;
    } else if (pointsLola > pointsErin) {
        return LOLA_WINS;
    } else {
        return DRAW;
    }
};

assert(roundWinner(1, 3, 2, 6) == ERIN_WINS);
assert(roundWinner(1, 6, 2, 3) == LOLA_WINS);
assert(roundWinner(1, 6, 2, 6) == DRAW);
assert(roundWinner(1, 3, 1, 3) == DRAW);
assert(gameWinner(2, 0) == ERIN_WINS);
assert(gameWinner(2, 1) == ERIN_WINS);
assert(gameWinner(1, 1) == DRAW); 

forall(UInt, fingersErin => 
    forall(UInt, fingersLola =>
        forall(UInt, guessErin =>
            forall(UInt, guessLola => 
                assert(isResult(roundWinner(fingersErin, guessErin, fingersLola, guessLola)))))));

forall(UInt, (fingersErin) => 
    forall(UInt, (fingersLola) =>
        forall(UInt, (guess) =>
            assert(roundWinner(fingersErin, guess, fingersLola, guess) == DRAW))));

forall(UInt, pointsErin => 
    forall(UInt, pointsLola => 
        assert(isResult(gameWinner(pointsErin, pointsLola)))));

const Player = {
    ...hasRandom,
    getFingers: Fun([], UInt),
    getGuess: Fun([], UInt),
    seeOutcome: Fun([UInt], Null),
    informTimeout: Fun([], Null),
};

export const main = Reach.App(() => {
    const Erin = Participant('Erin', {
        ...Player,
        wager: UInt,
    });

    const Lola = Participant('Lola', {
        ...Player,
        acceptWager: Fun([UInt], Null),
    });

    init();

    const informTimeout = () => {
        each([Erin, Lola], () => {
            interact.informTimeout();
        });
    };

    Erin.only(() => {
        const wager = declassify(interact.wager);
    });
    Erin.publish(wager)
        .pay(wager);
    commit();

    Lola.only(() => {
        interact.acceptWager(wager);
    });
    Lola.pay(wager)
        .timeout(relativeTime(DEADLINE), () => closeTo(Erin, informTimeout));

    var result = DRAW;
    invariant( balance() == 2 * wager && isResult(result) );
    while ( result == DRAW ) {
        commit();

        Erin.only(() => {
            const _fingersErin = interact.getFingers();
            const [_commitFingersErin, _saltFingersErin] = makeCommitment(interact, _fingersErin);
            const commitFingersErin = declassify(_commitFingersErin);

            const _guessErin = interact.getGuess();
            const [_commitGuessErin, _saltGuessErin] = makeCommitment(interact, _guessErin);
            const commitGuessErin = declassify(_commitGuessErin);
        });
        Erin.publish(commitFingersErin, commitGuessErin)
            .timeout(relativeTime(DEADLINE), () => closeTo(Lola, informTimeout));
        commit();
    
        unknowable(Lola, Erin(_fingersErin, _saltFingersErin, _guessErin, _saltGuessErin));

        Lola.only(() => {
            const _fingersLola = interact.getFingers();
            const fingersLola = declassify(_fingersLola);
    
            const _guessLola = interact.getGuess();
            const guessLola = declassify(_guessLola);
        });
        Lola.publish(fingersLola, guessLola)
            .timeout(relativeTime(DEADLINE), () => closeTo(Erin, informTimeout));
        commit();

        Erin.only(() => {
            const saltFingersErin = declassify(_saltFingersErin);
            const fingersErin = declassify(_fingersErin);

            const saltGuessErin = declassify(_saltGuessErin);
            const guessErin = declassify(_guessErin);
        });
        Erin.publish(saltFingersErin, fingersErin, saltGuessErin, guessErin)
            .timeout(relativeTime(DEADLINE), () => closeTo(Lola, informTimeout));
        checkCommitment(commitFingersErin, saltFingersErin, fingersErin);
        checkCommitment(commitGuessErin, saltGuessErin, guessErin);

        result = roundWinner(fingersErin, guessErin, fingersLola, guessLola);
        continue;
    };

    assert(result == ERIN_WINS || result == LOLA_WINS || result == DRAW);
    if (result == DRAW) {
        transfer(1 * wager).to(Erin);
        transfer(1 * wager).to(Lola);
    } else if (result == ERIN_WINS) {
        transfer(2 * wager).to(Erin);
    } else {
        transfer(2 * wager).to(Lola);
    }
    commit();

    each([Erin, Lola], () => {
        interact.seeOutcome(result);
    });
});
