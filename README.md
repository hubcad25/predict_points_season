# Random initial notes

- Each model will generate the uncertainty of the projection, a confidence interval.
- The schema of the architecture of the project is `schemas/main.png`
- Each rate-per-game will be adjusted by the number of games the player has played in a season as to regress extreme values to the initial season projection of the LSTMs. The more a player will have played games in a season, the less its rates will be adjusted.
- In the future: using the foundation from this model to build a model that predicts the ups and downs of player using time series and financial data models

# Meta parameters

## Dependent variables (components)

Each model will be composed of two submodels predicting two different dependent variables. For example, goals and assists are going to be two different submodels. The predictions from the two models will be added together to estimate the points of a player. The variances between the two models will be added together to compose the distribution of potential point outcomes of a player.

## Position

Models will be separated for F and D.

## Overview of model parameters

In total: 2 components (goals and assists) and 2 positions (F and D): 2 x 2 = 4 models.

# Game data independant variables to include in model

## Stable
[] Age
[] Height
[] Draft

## Time on ice
[] EV TOI 
[] PP TOI (via nhl api)
    - https://api.nhle.com/stats/rest/en/skater/timeonice?isAggregate=true&isGame=false&sort=%5B%7B%22property%22:%22timeOnIce%22,%22direction%22:%22DESC%22%7D,%7B%22property%22:%22playerId%22,%22direction%22:%22ASC%22%7D%5D&start=0&limit=1&cayenneExp=gameTypeId=2%20and%20seasonId%3C=20232024%20and%20seasonId%3E=20222023
[] Team PP %

## Team play
[] gameScore
[] gameScore of teammates (top 3 or 5 in TOI?)
[] onIce_xGoalsPercentage
[] finishing_lowDanger of teammates
[] finishing_mediumDanger of teammates
[] finishing_highDanger of teammates
[] finishing_rebounds of teammates

## Individual play-driving
[] I_F_xOnGoal
[] I_F_xGoals
[] I_F_xRebounds
[] I_F_xFreeze
[] I_F_xPlayContinuedInZone
[] I_F_flurryAdjustedxGoals
[] I_F_scoreVenueAdjustedxGoals
[] I_F_flurryScoreVenueAdjustedxGoals
[] I_F_shotAttempts
[] I_F_shotsOnGoal
[] *ability to place shots on net* I_F_shotsOnGoal / I_F_xOnGoal
[] I_F_reboundxGoals
[] I_F_lowDangerxGoals
[] I_F_mediumDangerxGoals
[] I_F_highDangerxGoals
[] I_F_xGoalsFromxReboundsOfShots
[] I_F_xGoalsFromActualReboundsOfShots
[] I_F_xGoals_with_earned_rebounds
[] I_F_xGoals_with_earned_rebounds_scoreAdjusted
[] I_F_xGoals_with_earned_rebounds_scoreFlurryAdjusted

## Finishing ability

[] *finishing_lowDanger* I_F_lowDangerGoals / I_F_lowDangerxGoals
[] *finishing_mediumDanger* I_F_mediumDangerGoals / I_F_mediumDangerxGoals
[] *finishing_highDanger* I_F_highDangerGoals / I_F_highDangerxGoals
[] *finishing_rebound* I_F_reboundGoals / I_F_reboundxGoals

## Other
[] I_F_takeaways
[] I_F_giveaways


# Structure of code files

Directories:

# Notable documentation
https://www.18skaters.com/2024/08/skater-point-projections-using-nhls-api.html


# Rookie model

Rookies will have a different model simply taking into account their former production, draft info, etc.

### Stable
[] Age
[] Height
[] Draft
[] Production in last 3 years
[] Projected TOI (non-naive)
[] Projected PP TOI (non-naive)