module Main where

import Data.IORef

import System.CloudyFS.Types

import qualified Data.ByteString.Char8 as B
import Foreign.C.Error
import System.Posix.Types
import System.Posix.Files
import System.Posix.IO

import System.Fuse

type HT = ()

mkDatabase :: IO Database
mkDatabase = newIORef ()

main :: IO ()
main = do
  db <- mkDatabase
  fuseMain (helloFSOps db) defaultExceptionHandler

helloFSOps :: Database -> FuseOperations HT
helloFSOps db = defaultFuseOps { fuseGetFileStat = helloGetFileStat
                            , fuseOpen = helloOpen db
                            , fuseRead = helloRead db
                            , fuseOpenDirectory = helloOpenDirectory
                            , fuseReadDirectory = helloReadDirectory
                            , fuseGetFileSystemStats = helloGetFileSystemStats
                            }
helloPath :: FilePath
helloPath = "/hello"
dirStat ctx = FileStat { statEntryType = Directory
                       , statFileMode = foldr1 unionFileModes
                                          [ ownerReadMode
                                          , ownerExecuteMode
                                          , groupReadMode
                                          , groupExecuteMode
                                          , otherReadMode
                                          , otherExecuteMode
                                          ]
                       , statLinkCount = 2
                       , statFileOwner = fuseCtxUserID ctx
                       , statFileGroup = fuseCtxGroupID ctx
                       , statSpecialDeviceID = 0
                       , statFileSize = 4096
                       , statBlocks = 1
                       , statAccessTime = 0
                       , statModificationTime = 0
                       , statStatusChangeTime = 0
                       }

fileStat fileName ctx = FileStat { statEntryType = RegularFile
                        , statFileMode = foldr1 unionFileModes
                                           [ ownerReadMode
                                           , groupReadMode
                                           , otherReadMode
                                           ]
                        , statLinkCount = 1
                        , statFileOwner = fuseCtxUserID ctx
                        , statFileGroup = fuseCtxGroupID ctx
                        , statSpecialDeviceID = 0
                        , statFileSize = fromIntegral $ length fileName
                        , statBlocks = 1
                        , statAccessTime = 0
                        , statModificationTime = 0
                        , statStatusChangeTime = 0
                        }

helloGetFileStat :: FilePath -> IO (Either Errno FileStat)
helloGetFileStat "/" = do
    ctx <- getFuseContext
    return $ Right $ dirStat ctx
helloGetFileStat path = do
    ctx <- getFuseContext
    return $ Right $ fileStat path ctx

helloOpenDirectory "/" = return eOK
helloOpenDirectory _ = return eNOENT

helloReadDirectory :: FilePath -> IO (Either Errno [(FilePath, FileStat)])
helloReadDirectory "/" = do
    ctx <- getFuseContext
    return $ Right [(".", dirStat ctx)
                   ,("..", dirStat ctx)
                   ,(helloName, fileStat helloName ctx)
                   ]
    where (_:helloName) = helloPath
helloReadDirectory _ = return (Left (eNOENT))

helloOpen :: Database -> FilePath -> OpenMode -> OpenFileFlags -> IO (Either Errno HT)
helloOpen database path mode flags = do
  db <- readIORef database
  case mode of
    ReadOnly -> return (Right ())
    _ -> return (Left eACCES)

helloRead :: Database -> FilePath -> HT -> ByteCount -> FileOffset -> IO (Either Errno B.ByteString)
helloRead _ path _ byteCount offset =
        return $ Right $ B.take (fromIntegral byteCount) $ B.drop (fromIntegral offset) (B.pack path)

helloGetFileSystemStats :: String -> IO (Either Errno FileSystemStats)
helloGetFileSystemStats str =
  return $ Right $ FileSystemStats
    { fsStatBlockSize = 512
    , fsStatBlockCount = 1
    , fsStatBlocksFree = 1
    , fsStatBlocksAvailable = 1
    , fsStatFileCount = 5
    , fsStatFilesFree = 10
    , fsStatMaxNameLength = 255
    }