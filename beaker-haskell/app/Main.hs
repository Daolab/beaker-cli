module Main where

import Commands

import Process
import Options.Applicative
import Data.Semigroup ((<>))
import qualified Data.Text as T
import qualified Network.Ethereum.Web3.Address as Address
import Network.Ethereum.Web3.Address (Address)

-- |Product data type containing all of the configuring input to the CLI.
data Options = Options
    { opts_command :: Command
    } deriving (Show)

-- |The possible commands that can be parsed by the commandline. The data
-- contained within each command is the necessary data for that command.
data Command
    -- |The "check" command reads a procedure and determines if it complies with
    -- what is required of a beaker procedure.
    = Check ReadOpt FilePath
    -- |Print the opcodes
    | PrintOpCodes ReadOpt FilePath
    -- |Print the structures
    | PrintStructures ReadOpt FilePath
    -- |The original "compile" command. Takes an input path and a possible
    -- output path.
    | Compile FilePath FilePath (Maybe Capabilities)
    -- |Deploy a kernel to the blockchain
    | Deploy
    -- |See the status of a kernel instance
    | InstanceStatus Address
    deriving (Eq, Show)

-- |A parser for all the commands. The parser will try each of these commands to
-- see if one parses successfully.
commands :: Parser Command
commands = subparser $ mconcat
    [ command "check" checkCommandParser
    , command "compile" compileCommandParser
    , command "opcodes" printOpCodesCommandParser
    , command "structures" printStructuresCommandParser
    , command "deploy" deployCommandParser
    , command "status" statusCommandParser
    ]

-- |Parse the "check" command.
checkCommandParser :: ParserInfo Command
checkCommandParser = info (Check <$> readOptParser <*> parseFilePath)
    (progDesc "Check that the procedure only contains beaker-compliant opcodes")

-- |Parse the "opcodes" command.
printOpCodesCommandParser :: ParserInfo Command
printOpCodesCommandParser = info (PrintOpCodes <$> readOptParser <*> parseFilePath)
    (progDesc "Print opcodes")

-- |Parse the "structures" command.
printStructuresCommandParser :: ParserInfo Command
printStructuresCommandParser = info (PrintStructures <$> readOptParser <*> parseFilePath)
    (progDesc "Print structures")

-- |Parse the "deploy" command.
deployCommandParser :: ParserInfo Command
deployCommandParser = info (pure Deploy)
    (progDesc "Deploy a new kernel to the network")

-- |Parse the "status" command.
statusCommandParser :: ParserInfo Command
statusCommandParser = info (InstanceStatus <$> parseAddress)
    (progDesc "Deploy a new kernel to the network")

parseAddress :: Parser Address
parseAddress = argument (eitherReader $ (Address.fromText . T.pack)) (metavar "ADDRESS")

readOptParser = option readOpt
    ( long "read"
    <> short 'r'
    <> metavar "READ_TYPE"
    <> value ReadBinary
    <> help "Type of read input" )

readOpt :: ReadM ReadOpt
readOpt = eitherReader $ \string -> case string of
    "bin"  -> Right ReadBinary
    "hex"  -> Right ReadHex
    "solc" -> Right ReadSolC
    _ -> Left "Invalid --read value"

-- |Parse the "compile" command.
compileCommandParser :: ParserInfo Command
compileCommandParser = info (Compile
    <$> parseFilePath
    <*> strArgument
        ( metavar "OUTPUT"
        <> value "output.abi"
        <> help "output abi file"
        )
    <*> optional capParser
    )
    (progDesc "The original compile function")

-- |Parse a filepath. Used in the various parsers for commands.
parseFilePath :: Parser FilePath
parseFilePath = argument str (metavar "INPUT-FILE")

capParser :: Parser Capabilities
capParser = Capabilities
    <$> option auto (
        long "write" <> help "write capabilities"
    )

cliParser :: Parser Options
cliParser = Options <$> commands

main :: IO ()
main = do
    cmd <- (execParser opts)
    process cmd
        where opts = info (cliParser <**> helper) fullDesc

process :: Options -> IO ()
process opts = do
    case opts_command opts of
        (Compile inPath outpath caps) -> runCompile inPath outpath caps
        (Check readOpt inPath) -> runCheck readOpt inPath
        (PrintOpCodes readOpt inPath) -> runOpCodes readOpt inPath
        (PrintStructures readOpt inPath) -> runStructures readOpt inPath
        (Deploy) -> runDeploy
        (InstanceStatus address) -> runStatus address
