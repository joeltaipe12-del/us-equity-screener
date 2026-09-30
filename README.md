# US Equity Screener

A five-factor screener and backtest over the S&P 100, 2020–2025.

**Stack:** PostgreSQL · DBeaver · Python · Tableau · Excel

**[→ Live dashboard](your-tableau-url)**

## The Question

If you rank the largest US companies on five measurable traits
and buy the top ten, would you have beaten the market?

## Executive Summary

A five-factor screener over the S&P 100 produced a top-ten portfolio
returning +317% against the index's +131% over 2020–2025, with lower
volatility and half the drawdown.

The benchmark's figures match the real S&P 500, confirming the
calculation chain is correct.

The strategy result is not, however, evidence that the strategy works.
Factor scores were computed using data through the end of the test
period and applied from the start of it, the universe contains only
companies that survived to the present, and the risk factor is scored
on the same window it is measured over.

What the project demonstrates is a working, reproducible analytics
pipeline — extraction, validation, dimensional modelling, window-function
analytics, backtesting and visualisation — together with the judgement
to identify why its own headline result should not be believed.

