# Random initial notes

- Each model will generate the uncertainty of the projection, a confidence interval.
- The schema of the architecture of the project is `schemas/main.png`
- Each rate-per-game will be adjusted by the number of games the player has played in a season as to regress extreme values to the initial projection using a simple ARIMA of the player's past seasons. The more a player will have played games in a season, the less its rates will be adjusted.
- In the future: using the foundation from this model to build a model that predicts the ups and downs of player using time series and financial data models

# Meta parameters

## Dependent variables (components)

Each model will be composed of two submodels predicting two different dependent variables. For example, goals and assists are going to be two different submodels. The predictions from the two models will be added together to estimate the points of a player. The variances between the two models will be added together to compose the distribution of potential point outcomes of a player.

## Position

Models will be separated for F and D.

## Overview of model parameters

In total: 2 components (goals and assists) and 2 positions (F and D): 2 x 2 = 4 models.

# Independant variables to include in points predictor model

List is in `documentation/independant_variables.ods`

## Time on ice (via NHL API)

https://api.nhle.com/stats/rest/en/skater/timeonice?isAggregate=true&isGame=false&sort=%5B%7B%22property%22:%22timeOnIce%22,%22direction%22:%22DESC%22%7D,%7B%22property%22:%22playerId%22,%22direction%22:%22ASC%22%7D%5D&start=0&limit=1&cayenneExp=gameTypeId=2%20and%20seasonId%3C=20232024%20and%20seasonId%3E=20222023


# Structure of scripts

The scripts will be structured into extractors, loaders and refiners.
Each script will have a header explaining its role.

# Notable documentation
https://www.18skaters.com/2024/08/skater-point-projections-using-nhls-api.html


# Rookie model

Rookies will have a different model simply taking into account their former production, draft info, etc.

- [] Age
- [] Height
- [] Draft
- [] Production in last 3 years
- [] Projected TOI (non-naive)
- [] Projected PP TOI (non-naive)