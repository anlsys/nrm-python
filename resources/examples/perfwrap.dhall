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
        < PerfwrapperDisabled
        | Perfwrapper :
            { perfFreq :
                { fromHz : Double }
            , perfLimit :
                { fromOps : Integer }
            }
        >.Perfwrapper
        { perfFreq = { fromHz = 1.0 }, perfLimit = { fromOps = +100000 } }
    , power =
        { policy =
            < NoPowerPolicy | DDCM | DVFS | Combined >.NoPowerPolicy
        , profile =
            False
        , slowdown =
            +1
        }
    , monitoring =
        { ratelimit = { fromHz = 1.0 } }
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