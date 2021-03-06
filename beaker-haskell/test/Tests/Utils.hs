{-# LANGUAGE OverloadedStrings #-}
module Tests.Utils where

import Control.Concurrent (threadDelay)
import Control.Exception
import Control.Monad.IO.Class

import Data.Attoparsec.ByteString
import Data.ByteString (pack)
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as C8 (pack, unpack)
import Data.ByteString.Base16 as B16
import qualified Data.Map as M
import Data.Maybe
import Data.Monoid (mempty, (<>))
import qualified Data.Set as S
import Data.Text.Encoding
import Data.Either

import Numeric.Natural

import Test.Framework (defaultMain, defaultMainWithOpts, testGroup)
import Test.Framework.Options (TestOptions, TestOptions'(..))
import Test.Framework.Runners.Options (RunnerOptions, RunnerOptions'(..))
import Test.Framework.Providers.HUnit
import Test.Framework.Providers.QuickCheck2 (testProperty)

import Test.QuickCheck
import Test.HUnit

import Check.Stores
import OpCode.Exporter
import OpCode.Parser
import OpCode.Type
import Process
import OpCode.Utils
import CompileSolidity
import Models.HandWritten

import Network.Ethereum.Web3 hiding (runWeb3)
import Network.Ethereum.Web3.Web3
import Network.Ethereum.Web3.JsonAbi as JsonAbi
import Network.Ethereum.Web3.Types
import Network.Ethereum.Web3.Eth as Eth
import qualified Network.Ethereum.Web3.Address as Address

import Data.List
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T

import System.Directory
import System.Environment
import System.FilePath
import System.Process
import System.IO.Temp

import Utils

nullRes :: Text
nullRes = "0x"

parseStorageLog :: Change -> (Address, Text)
parseStorageLog log = (address, storageKey)
    where
        storageKey = T.drop 40 $ T.drop 2 $ changeData log
        (Right address) = Address.fromText $ T.take 40 $ T.drop 2 $ changeData log

-- |Storage logs should also be ordered.
checkStorageLogs :: [(Address, Text)] -> [Change] -> Assertion
checkStorageLogs expectedLogInfo logs = do
    assertEqual "The number of logs should be equal to the number expected"
        (length expectedLogInfo) (length logs)
    mapM_ (\((a,b),c) -> checkStorageLog a b c) (zip expectedLogInfo logs)

checkStorageLog :: Address -> Text -> Change -> Assertion
checkStorageLog expectedContractAddress expectedStorageKey log = do
    let (logContractAddress, logStorageKey) = parseStorageLog log
    assertEqual "Log address should be correct" expectedContractAddress (changeAddress log)
    assertEqual "Log data address should be correct" expectedContractAddress logContractAddress
    assertEqual "Log data storage key should be correct" expectedStorageKey logStorageKey

