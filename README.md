# predict_points_season

## Intro

### Projection windows

Two projection windows:

-   1-year point projection
-   5-year point projection

Each model will generate the uncertainty of the projection, a confidence interval.

### Dependent variables

Each model will be composed of two submodels predicting two different dependent variables. For example, goals and assists are going to be two different submodels. The predictions from the two models will be added together to estimate the points of a player. The variances between the two models will be added together to compose the distribution of potential point outcomes of a player.

### Historic of independant variables

Models will also differ for how many seasons the player has played. Models for 3+seasons-historic, 2seasons-historic and 1season-historic will be created. The arbitrary cutoff will be at 10% of a season. If a player skips one season, the missing season will be filled with the former season data.

### Position

Models will be separated for F and D.

### Overview of model parameters

In total: 2 main models (1-year projection and 5-year projection), 2 components (goals and assists), 4 types of historical data (3, 2 and 1 years) and 2 positions (F and D): 2x2x3x2 = 24 models.

## Possible indepedent variables

Stable

-   Age (by season)
-   Draft rank (undrafted = 300)
-   Height

Rates per game

-   Shots from slot :
    -   all
    -   wristshot
    -   deflect
    -   backhand
    -   slapshot
-   Conversion % for shots from slot :
    -   all
    -   wristshot
    -   deflect
    -   backhand
    -   slapshot
-   Shots from wing :
    -   all
    -   wristshot
    -   deflect
    -   backhand
    -   slapshot
-   Conversion % for shots from wing :
    -   all
    -   wristshot
    -   deflect
    -   backhand
    -   slapshot
-   Shots from point :
    -   all
    -   wristshot
    -   deflect
    -   backhand
    -   slapshot
-   Conversion % for shots from point :
    -   all
    -   wristshot
    -   deflect
    -   backhand
    -   slapshot
-   Proportion of missed or blocked shots from slot :
    -   all
    -   wristshot
    -   deflect
    -   backhand
    -   slapshot
-   Proportion of missed or blocked shots from wings :
    -   all
    -   wristshot
    -   deflect
    -   backhand
    -   slapshot
-   Proportion of missed or blocked shots from point :
    -   all
    -   wristshot
    -   deflect
    -   backhand
    -   slapshot
-   ev toi (from in seasons data nhl api)
-   pp toi (from in seasons data nhl api)
-   weighted projection of dependent variable (goals or assist)

## Adjusted rate

Each rate-per-game will be adjusted by the number of games the player has played in a season as to regress extreme values to the mean. The more a player will have played games in a season, the less its rates will be adjusted.

## Projecting independent variables

To obtain estimates of a player's goal and assists for upcoming seasons, independent variables will need to be projected upon next season (or projected as of 3 seasons from now). These projections will depend on the historic parameter. Projections will be simple weighted means (recent seasons weighing more).

## Core pipeline

Tables in order in the core pipeline:

-   **pbp**: each observation is a shot attempt.
-   **warehouse** : each observation is one season of a player with raw values. For example, it contains the number of games played by the player in the season, his number of shots from the slots, his conversion from the slot, etc. Players will be identified by their player_id here. No stable information (name, draft rank, age, height, etc.) will be included at this point. F and D are mixed here. One column for each dependent variable.
-   **warehouse_adj** : same as warehouse, but with pace-adjusted values.
-   **marts/{suffix}** : marts will be the tables that are used to train the models. The suffix will indicate the projection window and the historic data parameters generated by this table. For example: `mart_w1-h2` will be the mart for the following model: 1 year window, 2 seasons of historic data. The mart will contain forwards and defensemen and will have both `g` and `a` variable. Positions and dependent variables will be dealt with in the training scripts.

## Structure of code files

Directories:

-   wrangling: contains files to go from **pbp** to the **marts**. One file for each *"bridge"*.
    -   `pbp-warehouse.R`: file that takes data from **pbp** and wrangles it as **warehouse**.

## Auxiliary data

Auxiliary data tables are generated by the R scripts of their name in the `auxiliary` folder.

-   player_infos: contains relevant players informations such as their date of birth, position, nationality, draft infos, etc. -nhl_drafts: contains the selections of every NHL draft.

## Using models to make predictions
