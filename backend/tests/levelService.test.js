const { computeLevel, POINTS, RANKS } = require('../src/services/levelService');

const stats = (extra = {}) => ({ account_days: 0, planted: 0, harvested: 0, plants: 0, seasons: 0, ...extra });

describe('gardener level', () => {
  test('a new account is a seed, the next rank is sprout', () => {
    expect(computeLevel(stats())).toMatchObject({ rank: 'seed', points: 0, rank_min: 0, next_rank: 'sprout', next_rank_min: 50 });
  });

  test('seniority counts, but is capped : it cannot replace gardening', () => {
    expect(computeLevel(stats({ account_days: 14 })).points).toBe(2 * POINTS.perWeek);
    const veryOld = computeLevel(stats({ account_days: 10 * 365 }));
    expect(veryOld.points).toBe(POINTS.seniorityMax);
    expect(veryOld.rank).toBe('sprout');
  });

  test('planting, harvesting, variety and seasons all give points', () => {
    const level = computeLevel(stats({ planted: 2, harvested: 1, plants: 2, seasons: 1 }));
    expect(level.points).toBe(2 * POINTS.perPlanted + POINTS.perHarvested + 2 * POINTS.perPlant + POINTS.perSeason);
  });

  test('each rank starts at its minimum, the last one has no next rank', () => {
    for (const [i, rank] of RANKS.entries()) {
      // exactly the minimum, with harvests only (10 points each)
      const level = computeLevel(stats({ harvested: rank.min / POINTS.perHarvested }));
      expect(level.rank).toBe(rank.code);
      expect(level.next_rank).toBe(RANKS[i + 1]?.code ?? null);
    }
  });
});
