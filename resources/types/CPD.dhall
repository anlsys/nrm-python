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

{ sensors :
    List
    { sensorKey :
        Text
    , sensorValue :
        { sensorTags :
            List { tag : Text }
        , source :
            { sourceTag : Text }
        , sensorMeta :
            { range :
                < Set :
                    { admissibleValues : List Text }
                | Interval :
                    { mix : Double, max : Double }
                >
            , frequency :
                < MaxFrequency :
                    { maxFrequency : Double }
                | FixedFrequency :
                    { fixedFrequency : Double }
                >
            }
        , sensorDesc :
            Optional Text
        }
    }
, actuators :
    List
    { actuatorKey :
        Text
    , actuatorValue :
        { actuatorTags :
            List { tag : Text }
        , target :
            { targetTag : Text }
        , actuatorMeta :
            { actuatorRange :
                < Set :
                    { admissibleValues : List Text }
                | Interval :
                    { mix : Double, max : Double }
                >
            }
        , actuatorDesc :
            Optional Text
        }
    }
, objective :
    { linearCombination :
        List { w : Double, x : { sourceTag : Text } }
    , direction :
        < Minimize | Maximize >
    }
}
