-- ******************************************************************************
--  Copyright 2019 UChicago Argonne, LLC.
--  (c.f. AUTHORS, LICENSE)
--
--  SPDX-License-Identifier: BSD-3-Clause
-- ******************************************************************************
--
--
--
--     this file is auto-generated by nrm, modifications will be erased.
--
--

{ name =
    "default"
, app =
    { slice =
        { cpus = +1, mems = +1 }
    , scheduler =
        < FIFO | HPC | Other : { _1 : Integer } >.FIFO
    , perfwrapper =
        False
    , power =
        { policy =
            < NoPowerPolicy | DDCM | DVFS | Combined >.NoPowerPolicy
        , profile =
            False
        , slowdown =
            +1
        }
    , monitoring =
        { ratelimit = +1 }
    }
, hwbind =
    False
, image =
    < Image :
        { path :
            Text
        , magetype :
            < Sif | Docker >
        , binds :
            Optional (List Text)
        }
    | NoImage
    >.NoImage
}
