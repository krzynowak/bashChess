#!/bin/bash

# 2 boards, 1 for each player
declare -a boardW
declare -a boardB

# Grid constants
gridHorizontal1="\e[1;30m  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
gridHorizontal2="\e[1;30m  #        #        #        #        #        #        #        #        #"
gridHorizontal3="      A        B        C        D        E        F        G        H   "

# keep track of who is moving next
player=1

# White chess pieces
W_P="\u2659"
W_N="\u2658"
W_B="\u2657"
W_R="\u2656"
W_Q="\u2655"
W_K="\u2654"

# Black chess pieces
B_P="\u265F"
B_N="\u265E"
B_B="\u265D"
B_R="\u265C"
B_Q="\u265B"
B_K="\u265A"


# Initialize the game
function init()
{
    # Init array
    for num in {0..63}
    do
        boardW[$num]=" "
        boardB[$num]=" "
    done

    # Pawns
    for num in {8..15}
    do
        boardW[$num+40]=$W_P
        boardB[$num]=$B_P
    done

    # knights
    boardW[57]=$W_N
    boardW[62]=$W_N
    boardB[1]=$B_N
    boardB[6]=$B_N
    # bishops
    boardW[58]=$W_B
    boardW[61]=$W_B
    boardB[2]=$B_B
    boardB[5]=$B_B
    # rooks
    boardW[56]=$W_R
    boardW[63]=$W_R
    boardB[0]=$B_R
    boardB[7]=$B_R
    # queen
    boardW[59]=$W_Q
    boardB[3]=$B_Q
    # king
    boardW[60]=$W_K
    boardB[4]=$B_K

    #scores
    scoreB=39
    scoreW=39
}

# Return string figure for particular field from either board
function getField()
{
    if [ "${boardW[$1]}" != " " ]
    then
        field="\e[0m${boardW[$1]}\e[1;30m"
    elif [ "${boardB[$1]}" != " " ]
    then
       field="\e[0m${boardB[$1]}\e[1;30m"
    else
        field=" "
    fi
}

# function to dispaly chess board
function displayGrid()
{
    echo -e "$gridHorizontal3"
    echo -e "$gridHorizontal1"

    for row in {0..7}
    do
        str="\e[0m$(expr 8 - $row) \e[1;30m"

        for col in {0..7}
        do
            idx=$row*8+$col

            getField $idx

            let "idx=$row*8+$col"

            tmp="#   "$field"    "

            str="$str$tmp"
        done

        echo -e "$gridHorizontal2"
        echo -e "$str#"" \e[0m$(expr 8 - $row) \e[1;30m"
        echo -e "$gridHorizontal2"
        echo -e "$gridHorizontal1\e[0m"
    done

    echo -e "$gridHorizontal3"
}

# Cyclic function with base logic for most moves
function getInputs()
{ 
    echo "Figure to move:"
    while true
    do
        read start

        if [ 2 -eq ${#start} ]
        then
            # parse input
            printf -v Xs '%d' "'${start::1}"
            X1=$(expr $Xs - 97)
            Y1=${start:1:2}
            Y1=$(expr $Y1 - 1)
            Y1=$(expr 7 - $Y1)

            # check if input is valid
            if (($X1 >= 0 && $X1 < 8 && $Y1 >= 0 && $Y1 < 8 ))
            then
                # calcualte index
                let "idxS=$Y1*8+$X1"

                # check if current player has piece at given index
                if [ $player -eq 1 ]
                then
                    piece=${boardW[$idxS]}
                else
                    piece=${boardB[$idxS]}
                fi

                if [  "$piece" == " " ]
                then
                    echo "No valid chess piece. Try again"
                else
                    # found piece move on
                    break
                fi
            else
                echo "Wrong coords ($X1, $Y1). Try again"
            fi
        else
            echo "Wrong coord size. Try again"
        fi
    done


    echo "Move destination (\"r\" - reset to piece selection):"
    while true
    do
        # get destination index
        read dest

        if [ 2 -eq ${#dest} ]
        then
            # parse input
            printf -v Xs '%d' "'${dest::1}"
            X2=$(expr $Xs - 97)
            Y2=${dest:1:2}
            Y2=$(expr $Y2 - 1)
            Y2=$(expr 7 - $Y2)

            # check if valid
            if (($X2 >= 0 && $X2 < 8 && $Y2 >= 0 && $Y2 < 8 ))
            then
                # calcualte index
                let "idxE=$Y2*8+$X2"

                # get piece
                if [ $player -eq 1 ]
                then
                    destF=${boardW[$idxE]}
                else
                    destF=${boardB[$idxE]}
                fi

                # check if destination idnex is valid
                if [  "$destF" != " " ]
                then
                    echo "Can't move onto your own piece. Try again"
                else
                    # check if slected piece can move in a pattern, that reaches destination
                    checkMoveDest $piece $X1 $Y1 $X2 $Y2 $idxS $idxE
                    if [ 1 -eq $canMove ]
                    then
                        # make sure path is not bostructed by another piece
                        checkPath $piece $X1 $Y1 $X2 $Y2

                        if [ 1 -eq $validPath ]
                        then
                            # check special condtions, e.g. pawn moving 2 spaces, figure taken, etc.
                            evalDest $piece $idxE $Y2

                            # move to destionation/update board
                            performMove $idxS $idxE
                            break
                        else
                            echo "Path obstructed, try again:"
                        fi
                    else
                        echo "Wrong destination try again:"
                    fi
                fi
            else
                echo "Wrong coords ($X2, $Y2). Try again"
            fi
        # possibly reset input 'r'
        elif [ 1 -eq ${#dest} ] && [ "r" == $dest ]
        then
            # turn finished
            break
        else
            echo "Wrong coord size. Try again"
        fi
    done

}

# check if neither player has a piece at destionation
function checkIfFiledEmpty()
{
    let "spotIdx=$2*8+$1"

    if [ " " != "${boardW[$spotIdx]}" ] || [ " " != "${boardB[$spotIdx]}" ]
    then
        validPath=0
    fi
}

# check if field contians opponents figgure
function checkIfFiledHasEnemy()
{
    let "spotIdx=$2*8+$1"

    if [ " " == "${boardW[$spotIdx]}" ] && [ " " == "${boardB[$spotIdx]}" ]
    then
        validPath=0
    fi
}

# check if pawn can treverse path kill enemy sideway or move forward wityhotu obstruction
function checkPathPawn()
{
    validPath=1

    dX=$(expr $2 - $4)
    dY=$(expr $1 - $3)

    if [ $player -eq 1 ]
    then
        if [ 1 -eq $dX ] #move 1 forward
        then
            if [ 0 -eq $dY ] # only forward
            then
                checkIfFiledEmpty $1 $4
            elif [ -1 -eq $dY ] || [ 1 -eq $dY ] #take figure on diagonal
            then
                checkIfFiledHasEnemy $3 $4
            fi

        elif [ 2 -eq $dX ] # move 2 fields forward
        then
            checkIfFiledEmpty $1 $(expr $2 - 1)
            checkIfFiledEmpty $1 $(expr $2 - 2)
        fi
    else    #same as above but other player
        if [ -1 -eq $dX ]
        then 
            if [ 0 -eq $dY ]
            then
                checkIfFiledEmpty $1 $4
            elif [ -1 -eq $dY ] || [ 1 -eq $dY ]
            then
                checkIfFiledHasEnemy $3 $4
            fi
        elif [ -2 -eq $dX ]
        then
            checkIfFiledEmpty $1 $(expr $2 + 1)
            checkIfFiledEmpty $1 $(expr $2 + 2)
        fi
    fi
}

# check if bishop can move unobstructed
function checkPathBishop()
{
    validPath=1

    # figure out directions and check
    if [ $1 -lt $3 ]
    then
        if [ $2 -lt $4 ]
        then
            for ((i=$1+1, j=$2+1; i!=$3; i++,j++))
            do 
                checkIfFiledEmpty $i $j
            done
        else
            for ((i=$1+1, j=$2-1; i!=$3; i++,j--))
            do 
                checkIfFiledEmpty $i $j
            done
        fi
    else
        if [ $2 -lt $4 ]
        then
            for ((i=$1-1, j=$2+1; i!=$3; i--,j++))
            do 
                checkIfFiledEmpty $i $j
            done
        else
            for ((i=$1-1, j=$2-1; i!=$3; i--,j--))
            do 
                checkIfFiledEmpty $i $j
            done
        fi
    fi
}

# check if rook can move unobstructed
function checkPathRook()
{
    validPath=1

    # figure out directions and check
    if [ $1 -eq $3 ]
    then
        if [ $2 -lt $4 ]
        then
            for ((i=$2+1; i!=$4; i++))
            do 
                checkIfFiledEmpty $1 $i
            done
        else
            for ((i=$2-1; i!=$4; i--))
            do 
                checkIfFiledEmpty $1 $i
            done
        fi
    elif [ $2 -eq $4 ]
    then
        if [ $1 -lt $3 ]
        then
            for ((i=$1+1; i!=$3; i++))
            do 
                checkIfFiledEmpty $2 $i
            done
        else
            for ((i=$1-1; i!=$3; i--))
            do 
                checkIfFiledEmpty $2 $i
            done
        fi
    fi
}

# perform path check based on figure moving
function checkPath()
{
    validPath=0

    case $1 in

    # knight and king always succeed
    "$W_N"|"$B_N"|"$W_K"|"$B_K")
        validPath=1
        ;;

    # pawn
    "$W_P"|"$B_P")
        checkPathPawn $2 $3 $4 $5
        ;;

    # bishop
    "$W_B"|"$B_B")
        checkPathBishop $2 $3 $4 $5
        ;;

    # rook
    "$W_R"|"$B_R")
        checkPathRook $2 $3 $4 $5
        ;;

    # queen
    "$W_Q"|"$B_Q")
        if [ 1 -eq $quenType ]
        then
            checkPathRook $2 $3 $4 $5
        elif [ 2 -eq $quenType ]
        then
            checkPathBishop $2 $3 $4 $5
        else
            echo "Queen move error"
        fi

        quenType=0
        ;;

    *)
        echo "ERROR checkPath"
        ;;
    esac
}

# check if destination field can be reached by figured
function checkMoveDest()
{
    canMove=0

    # test if any of the possible move patterns matches what player declared
    case $1 in
    # pawn
    "$W_P"|"$B_P")
        dX=$(expr $3 - $5) 

        if [ $player -eq 1 ]
        then
            if [ 1 -eq $dX ]
            then 
                canMove=1
            elif (( 2 == $dX && 6 == $3 ))
            then
                canMove=1
            fi
        else
            if [ -1 -eq $dX ]
            then 
                canMove=1
            elif (( -2 == $dX && 1 == $3 ))
            then
                canMove=1
            fi
        fi
        ;;

    # knight
    "$W_N"|"$B_N")
        dX=$(expr $3 - $5) 
        dY=$(expr $2 - $4)
        dX=${dX#-}
        dY=${dY#-}

        if (( ( 2 == $dX && 1 == $dY ) || ( 1 == $dX && 2 == $dY ) ))
        then
            canMove=1
        fi
        ;;

    # bishop
    "$W_B"|"$B_B")
        dX=$(expr $3 - $5) 
        dY=$(expr $2 - $4)
        dX=${dX#-}
        dY=${dY#-}

        if (( $dX == $dY ))
        then
            canMove=1
        fi
        ;;

    # rook
    "$W_R"|"$B_R")
        dX=$(expr $3 - $5) 
        dY=$(expr $2 - $4)
        dX=${dX#-}
        dY=${dY#-}

        if (( ( 0 != $dX && 0 == $dY ) || ( 0 == $dX && 0 != $dY ) ))
        then
            canMove=1
        fi
        ;;

    # queen
    "$W_Q"|"$B_Q")
        dX=$(expr $3 - $5) 
        dY=$(expr $2 - $4)
        dX=${dX#-}
        dY=${dY#-}

        if (( ( 0 != $dX && 0 == $dY ) || ( 0 == $dX && 0 != $dY ) ))
        then
            #Rook
            canMove=1
            quenType=1
        fi

        if (( $dX == $dY ))
        then
            #Bishop
            canMove=1
            quenType=2
        fi
        ;;

    # king
    "$W_K"|"$B_K")
        dX=$(expr $3 - $5) 
        dY=$(expr $2 - $4)
        dX=${dX#-}
        dY=${dY#-}

        if (( ( 1 == $dX && 1 == $dY ) || ( 1 == $dX && 0 == $dY ) || ( 0 == $dX && 1 == $dY ) ))
        then
            canMove=1
        fi
        ;;
    *)
        echo "ERROR checkMoveDest"
        ;;
    esac
}

# if pawns hits the end he gets promoted
function promotePawn()
{
    if [ $promote -eq 1 ]
    then

        echo "Pawn gets promoted choose Figure (Knight (n), Bishop (b), Rook(r), Queen(q) ):"

        while [ $promote -eq 1 ]
        do
            promote=0
            # read slected promotion position and update score
            read promotion

            if [ $player -eq 1 ]
            then
                case $promotion in
                # knight
                "n")
                    boardW[$1]=$W_N
                    pointChange=2
                    ;;
                # bishop
                "b")
                    boardW[$1]=$W_B
                    pointChange=2
                    ;;
                # rook
                "r")
                    boardW[$1]=$W_R
                    pointChange=4
                    ;;
                # queen
                "q")
                    boardW[$1]=$W_Q
                    pointChange=8
                    ;;
                *)
                    promote=1
                    echo "Try again:"
                    ;;
                esac
            else
                case $promotion in
                # knight
                "n")
                    boardW[$1]=$B_N
                    pointChange=2
                    ;;
                # bishop
                "b")
                    boardW[$1]=$B_B
                    pointChange=2
                    ;;
                # rook
                "r")
                    boardW[$1]=$B_R
                    pointChange=4
                    ;;
                # queen
                "q")
                    boardW[$1]=$B_Q
                    pointChange=8
                    ;;
                *)
                    promote=1
                    echo "Try again:"
                    ;;
                esac
            fi
        done

        if [ $player -eq 1 ]
        then
            let "scoreW=$scoreW+$pointChange"
        else
            let "scoreB=$scoreB+$pointChange"
        fi
    fi
}

function evalDest()
{
    pointChange=0

    if [ $player -eq 1 ]
    then
        target=${boardB[$2]}
    else
        target=${boardW[$2]}
    fi

    promote=0

    # evaluate conssequences of move based on destination
    case $target in
    # pawn
    "$W_P"|"$B_P")
        pointChange=1
        figureTaken="(Pawn Taken)"
        ;;
    # knight
    "$W_N"|"$B_N")
        pointChange=3
        figureTaken="(Knight Taken)"
        ;;
    # bishop
    "$W_B"|"$B_B")
        pointChange=3
        figureTaken="(Bishop Taken)"
        ;;
    # rook
    "$W_R"|"$B_R")
        pointChange=5
        figureTaken="(Rook Taken)"
        ;;
    # queen
    "$W_Q"|"$B_Q")
        pointChange=9
        figureTaken="(Queen Taken)"
        ;;
    # king
    "$W_K")
        figureTaken="(White King Falls)"
        winner="B"
        ;;
    "$B_K")
        figureTaken="(Black King Falls)"
        winner="W"
        ;;
    *)

        ;;
    esac

    # check if promotion should occur
    if [ $1 == "$W_P" ] || [ $1 == "$B_P" ]
    then
        if [ $3 -eq 0 ] && [ $player -eq 1 ]
        then
            promote=1
        elif [ $3 -eq 7 ] && [ $player -ne 1 ]
        then
            promote=1
        fi
    fi

    # update score
    if [ $player -eq 1 ]
    then
        let "scoreB=$scoreB-$pointChange"
    else
        let "scoreW=$scoreW-$pointChange"
    fi
}

# updated board due to valid move
function performMove()
{
    if [ $player -eq 1 ]
    then
        boardW[$2]=${boardW[$1]}
        boardW[$1]=" "
        boardB[$2]=" "
    else
        boardB[$2]=${boardB[$1]}
        boardB[$1]=" "
        boardW[$2]=" "
    fi

    # check if pawn promotion should occur for this move
    promotePawn $2
}

# dispaly basic data
function playerDisp()
{
    echo "White score: $scoreW"
    echo "Black score: $scoreB"
    echo ""
    if [ 1 -eq $1 ]
    then
        echo "Turn of White"
    else
        echo "Turn of Black"
    fi
}

# main loop of script
function main()
{
    # no winner for now
    winner="N"

    # init board
    init

    # display grid
    displayGrid

    # display player data
    playerDisp $player

    # run main functionality
    getInputs
    
    # if player reset don't change player turn
    if [ "r" != $dest ]
    then
        let "player=player%2+1"
    fi

    # clear board
    clear

    # run until someone wins
    while true
    do
        # display board
        displayGrid

        # if no reset show last move 
        if [ "r" != $dest ]
        then
            echo "Last move: $start --> $dest $figureTaken"
            figureTaken=""
        fi

        # display player data
        playerDisp $player

        # run main functionality
        getInputs

        # someone won?
        if [ "$winner" == "W" ]
        then
            echo "White Wins"
            return 0
        elif [ $winner == "B" ]
        then
            echo "Black Wins"
            return 0
        else
            # no winner clear board
            clear
            
            # if player reset don't change player turn
            if [ "r" != $dest ]
            then
                let "player=player%2+1"
            fi
        fi
    done
}

main