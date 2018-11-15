module Hooridor.Gui where

import Hooridor.Core
import Graphics.Gloss
import Graphics.Gloss.Interface.Pure.Game
import Data.List 

type Board = Cell -> Color

defaultCellColor :: Color
defaultCellColor = black

data GuiState = GuiState GameState Board

data CellOrWall = Cell' Cell | Wall' Wall
  deriving (Show)

-- TODO: Generalize for size
build :: (Int,Int) -> (Float, Float)
build (x,y) = ((fromIntegral (x-4)*50),(fromIntegral (y-4)*50))

-- | Same as above
inverseBuild :: (Float, Float) -> (Int,Int)
inverseBuild (x,y) = (((round (x/50))+4),((round (y/50))+4))

-- fix wall placement
inverseBuild' :: (Float, Float) -> Maybe CellOrWall
inverseBuild' (x, y)
  | row < 0 || row > 8 || col < 0 || row > 8 = Nothing
  | not addRow && not addCol = Just (Cell' (row, col))
  | addRow && not addCol = Just (Wall'
      (((row, col), (row + 1, col))
       , ((row, col + 1), (row + 1, col + 1))))
  | not addRow && addCol = Just (Wall'
      (((row, col), (row, col + 1))
       , ((row + 1, col), (row + 1, col + 1))))
  | addRow && addCol = Nothing
  where
    y' = round x + 220 :: Int
    x' = round y + 220 :: Int
    (xDiv, xMod) = divMod x' 50
    (yDiv, yMod) = divMod y' 50
    row = yDiv 
    addRow = yMod > 40
    col = xDiv
    addCol = xMod > 40

makeBoard :: Cell -> Color -> Board
makeBoard cell color = f
  where
    f c
      | c == cell = color
      | otherwise = defaultCellColor

-- | Respond to key events.
handleEvents :: Event -> GuiState -> GuiState
handleEvents (EventKey (MouseButton _) Down _ (x', y')) gs =
  case obj of
    Just (Cell' a) -> GuiState (tryMove (MakeMove a) gameState) board
    Just (Wall' a) -> GuiState (tryMove (PutWall a) gameState) board
    Nothing -> gs
  where 
    (GuiState gameState board) = gs
    obj = inverseBuild' (x',y')
    (x,y) = inverseBuild (x',y')
handleEvents (EventMotion (x',y')) gs
  = GuiState (gameState) (makeBoard (x,y) (dark c))
  where 
    (GuiState gameState _) = gs
    (x,y) = inverseBuild (x',y')
    c = colorPlayer (pcolor (currentPlayer gameState))
handleEvents (EventKey (Char 'r') _ _ _) _ = initiateGame 2 8
handleEvents _ z = z

window :: Display
window = InWindow "Hooridor? A?" (600, 600) (0, 0)

background :: Color
background = white

fps :: Int
fps = 60

colorPlayer :: PlayerColor -> Color
colorPlayer Red = red
colorPlayer Green = green
colorPlayer Yellow = yellow
colorPlayer Orange = orange

drawPlayer :: Player -> Picture
drawPlayer p = translate x y (color (colorPlayer (pcolor p)) (circleSolid 15))
  where 
    (xr,yr) = pos p
    (x,y) = build (xr,yr)

drawCell :: Cell -> Board -> Picture
drawCell cell board = translate x' y' ((color c (rectangleSolid 40 40)))
  where 
    c = board cell
    (x',y') = build cell


drawWallSegment :: WallPart -> Color -> Picture
drawWallSegment wp col 
  | abs(x1-x2) == 0 = translate x y (color col (rectangleSolid 40 5)) 
  | otherwise = translate x y (color col (rectangleSolid 5 40))
  where
    (c1,c2) = wp
    (x1,y1) = build c1
    (x2,y2) = build c2 --TODO Refactor together with next func
    (x,y) = segmentCoordinates wp

segmentCoordinates :: WallPart -> (Float,Float)
segmentCoordinates (c1,c2) = (x,y)
  where
    (x1,y1) = build c1
    (x2,y2) = build c2
    x = (x1+x2)/2
    y = (y1+y2)/2

drawWall :: Color  -> Wall  -> Picture
drawWall c (ws1,ws2) = (drawWallSegment ws1 c) 
  <> (drawWallSegment ws2 c) 
  <> translate x y (color c (rectangleSolid 10 10))
  where 
    (x1,y1) = segmentCoordinates ws1
    (x2,y2) = segmentCoordinates ws2
    x = (x1+x2)/2
    y = (y1+y2)/2

drawBoard :: Board -> Picture
drawBoard board = pictures cellPictures
  where
    cellPictures
      = concatMap (\x -> map (\y -> drawCell (x, y) board) [0..8]) [0..8]

drawVictoryScreen :: Color -> Picture
drawVictoryScreen c = translate (-220) 0 (color (dark c) message)
  where 
    message = (scale 0.5 1 (text "You have won!"))

render :: Int -> GuiState -> Picture
render size (GuiState gameState board) =
  case winner of
    Nothing ->  translate x y (drawBoard board <>
        pictures (map drawPlayer (players)))          
        <> pictures (map (drawWall black) (walls gameState))  
    Just p -> drawVictoryScreen (colorPlayer (pcolor p))
    where 
      winner = find isWinner players
      (x,y) = (0,0) --build (-size,-size)
      players = playerList (gameState)
      testSegment1 = ((0,1),(1,1))
      testSegment2 = ((0,0),(1,0))
      testSegmentHorizontal = ((0,0),(0,1))

-- Create new GuiState with board of given size                        
initiateGame :: Int -> Int -> GuiState
initiateGame pc size = GuiState (initialState pc) allBlack
  where 
    allBlack _ = defaultCellColor

newBoard :: Board
newBoard = [ ((x,y),black) | x<-[0..8], y<-[0..8]]

-- Update per time
update :: Float -> GuiState -> GuiState
update _ = id

-- Start a game on a board with this size and for this number of players
playGame :: Int-> Int -> IO ()
playGame size pc
  = play window background fps
    (initiateGame pc size) (render size)
    handleEvents update
