--!strict
-- Server entry point. The sequence lives in Boot so the smoke test can run it
-- too; see Boot.luau.

require(script.Boot).Run(script.Services)
