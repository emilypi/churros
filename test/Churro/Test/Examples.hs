{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE Arrows #-}

-- | A set of examples of more complicated and problematic Churros.
-- 
module Churro.Test.Examples where

import Data.Map (fromList)
import Data.List

import Prelude hiding (id, (.))

import Control.Churro

-- $setup
-- 
-- >>> import System.Timeout (timeout)

-- ** Tests

-- | Checks that the IO nature of the churros doesn't duplicate operations.
--   Actions within a pipeline should only occur once no matter how the
--   pipeline is composed.
--
-- >>> runWaitChan linear
-- Debugging [l1]: 1
-- Debugging [l2]: 1
-- Debugging [r1]: 1
-- Debugging [r2]: 1
-- 1 
--
linear :: Transport t => Churro t Void Void
linear = sourceList [1::Int]
    >>> ((processDebug "l1" >>> processDebug "l2") >>> processDebug "r1" >>> processDebug "r2")
    >>> sinkPrint

-- | A more complicated pipeline exampe involving maps.
-- 
-- >>> runWaitChan pipeline
-- (fromList [(0,0),(1,1)],fromList [(1,1),(2,2)])
-- (fromList [(1,1),(2,2)],fromList [(2,2),(3,3)])
pipeline :: ChurroChan Void Void
pipeline = sourceList (take 3 maps)
        >>> withPrevious
        >>> takeC (10 :: Int)
        >>> sinkPrint
    where
    maps    = map fromList $ zipWith zip updates updates
    updates = map (take 2) (tails [0 :: Int ..])

-- | Consumers terminaiting should kill sources from producing.
-- 
-- This seems to sometimes fail in the following scenarios:
-- 
-- >>> timeout 1500000 $ runWaitChan $ sourceList [1..5] >>> delay 1 >>> takeC 1 >>> sinkPrint
-- 1
-- Just ()
-- 
-- What should happen is that the Category instance composition of:
-- 
--  ...  delay 1 >>> takeC 1  ...
--  ^^^ PRE ^^^^     ^^^ POST ^^^
-- 
-- When POST terminates it should cancel the computation in PRE.
-- 
-- The failures may be caused by one of the following:
-- 
-- * Nested Async actions don't cascade on cancellation (most likely, try using resource)
-- * The associativity laws of Category are broken, meaning that cancellation doesn't behave as it should.
-- * Producer blocks cancellation from being requested
-- * Chan is blocked preventing indicating termination to consumers
-- * Infinite source is causing issues (ruled out with this test example)
-- 