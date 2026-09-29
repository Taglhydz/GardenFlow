// Level of a gardener : it proves both their seniority and their mastery of the garden.
// Computed from the data each time (never stored), so it always matches what the user has done.
// Ranks are codes, translated by the app (level.ranks.<code>).

/** Points : seniority (capped, it can't replace gardening) + what was grown. */
const POINTS = {
  perWeek       : 2,    // account age
  seniorityMax  : 100,  // ~1 year : alone, it gets to sprout at most
  perPlanted    : 5,    // crop put in the ground
  perHarvested  : 10,   // crop harvested
  perPlant      : 15,   // different plant grown (variety)
  perSeason     : 20,   // season (3 months) with crops : coming back year after year
};

/** Ranks and the points they start at, from the lowest */
const RANKS = [
  { code: 'seed'            , min: 0    },
  { code: 'sprout'          , min: 50   },
  { code: 'seedling'        , min: 150  },
  { code: 'gardener'        , min: 350  },
  { code: 'skilled_gardener', min: 700  },
  { code: 'master_gardener' , min: 1200 },
];

/**
 * @param {{ account_days: number, planted: number, harvested: number, plants: number, seasons: number }} stats
 * @returns {{ rank, points, rank_min, next_rank, next_rank_min, stats }} next_rank(_min) are null at the top rank
 */
const computeLevel = (stats) => {
  const seniority = Math.min(Math.floor(stats.account_days / 7) * POINTS.perWeek, POINTS.seniorityMax);
  const points = seniority
    + stats.planted   * POINTS.perPlanted
    + stats.harvested * POINTS.perHarvested
    + stats.plants    * POINTS.perPlant
    + stats.seasons   * POINTS.perSeason;

  const index = RANKS.findLastIndex((rank) => points >= rank.min);
  const next  = RANKS[index + 1] ?? null;

  return {
    rank         : RANKS[index].code,
    points,
    rank_min     : RANKS[index].min,
    next_rank    : next?.code ?? null,
    next_rank_min: next?.min ?? null,
    stats,
  };
};

module.exports = { POINTS, RANKS, computeLevel };
