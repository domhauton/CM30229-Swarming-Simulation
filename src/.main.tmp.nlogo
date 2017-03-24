;;  The impact of ecological constraints on a model of altruistic communication --

;; This version of the simulation was written by Joanna Bryson while a fellow of the Konrad Lorenz Institute for Evolution and Cognition Research, while on sabbatical from the University of Bath.
;; It is based on a simulation by Cace and Bryson (2005, 2007).

extensions [csv]

globals [
  show-knowledge
  p-food-knowledge-list                   ;; the chance that a turtle will know how to exploit a new foodtype at birth (FIXME should be a slider)
  num-special-food-strat      ;; num-food-types - 1, often useful.
  expected-graph-max          ;; what we expect the Y axis to run to on the big combined plot
  foodstrat-graph-const       ;; multiplier based on num-food-types for the combined plot
  turtle-colour               ;; social turtle colour
  ktc                         ;; turtles-that-know-something-you-are-looking-at colour

  turtle-move-speed
  turtle-lifespan

  start-colony-cnt
  start-colony-turtle-cnt

  reproduction-age-min
  reproduction-energy-min

  num-food-types
  food-max
  food-grow-size
  food-death-chance
  food-base-energy-value

  learning-rate
  learning-success-chance
  learning-distance

  learning-change-difficulty

  swarming-distance
  swarming-energy
  ;; SLIDER swarming-probability
]



patches-own [
  foodCountList
]

turtles-own [
  age
  energy
  food-knowledge-list
]


to setup
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  clear-all
  setup-globals
  setup-patches
  setup-agents
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Globals
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-globals
  set reproduction-age-min 15
  set reproduction-energy-min 45

  set turtle-move-speed 3
  set turtle-lifespan 65

  set num-food-types 1
  set food-max 5                         ; max food per tile-slot
  set food-base-energy-value 3           ; value of food with 0 knowledge
  set food-grow-size 2                   ; food grows by 2 units every tick
  set food-death-chance 0.03             ; chance all food on a tile has of dieing every tick

  set start-colony-cnt 10                ; number of turtle colonies at the start
  set start-colony-turtle-cnt 50         ; number of turtles per colony

  set learning-rate 0.02                 ; The speed at which learning can take place
  set learning-success-chance 0.4        ; The chance of learning being >0
  set learning-distance 1.0              ; The distance to the teacher the learner must be
  set learning-change-difficulty 1       ; How much should the learners previous knowledge be weighted

  set swarming-distance 10.0             ; Distance at which turtle can observe other turtles to swarm to
  set swarming-energy 45                 ; Threshold at which a turtle may start to swarm
  ;; SLIDER set swarming-probability 0.5 ; Chance of a turtle swarming

  set expected-graph-max 8000                                               ; hard coded from looking at graphs
  set foodstrat-graph-const expected-graph-max / num-food-types             ; see update-plot-all

  set turtle-colour 97           ; color for ignorant turtles when using the "show knowledge" buttons
  set ktc 125                    ; color for turtles who know what you want to check on, as per previous line
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Run Simulations
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Run the simulation 50 times up to 1300 ticks recording knowledge density to a csv file over every run every 100 ticks
to run-simulation-to-file
  let filename (word "sim-results-" swarming-probability ".csv")
  IF FILE-EXISTS? filename [
    FILE-DELETE filename
  ]
  let knowledge-record-main (n-values 50 [(n-values 13 [0.1])])
  let cnt-outer 0
  repeat 50 [
    setup
    let knowledge-record (n-values 14 [0.1])
    let cnt-inner 1
    repeat 13 [
      repeat 100 [
        go
      ]
      set knowledge-record (replace-item cnt-inner knowledge-record avg-knowledge)
      set cnt-inner (cnt-inner + 1)
    ]
    set knowledge-record-main (replace-item cnt-outer knowledge-record-main knowledge-record)
    set cnt-outer (cnt-outer + 1)
  ]
  csv:to-file filename knowledge-record-main
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Patches
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Fill patches with food 60 times, to reach a sustainable level.
to setup-patches
  ask patches [
    set foodCountList (n-values num-food-types [0])
    repeat 60 [
      fill-patches-food-energy-value
    ]
    update-patches
  ]
end

; on every cycle, each patch has a food-replacement-rate% chance of being filled with grass, whether it had food there before or not.
to fill-patches-food-energy-value
  if (random-float 1.0 < food-replacement-rate) [
    set foodCountList (add-food (random num-food-types) foodCountList)          ;; add food-energy-value food
  ]
end

; on every cycle, each patch has a food-death-chance% chance of being filled with grass, whether it had food there before or not.
to decay-existing-food
    if (random-float 1.0 < food-death-chance) [
      set foodCountList (remove-food foodCountList)          ;; add food-energy-value food
    ]
end

to update-patches
   set pcolor (sum foodCountList)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Turtles
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-agents
  repeat start-colony-cnt [
    let colony-xcor random-xcor
    let colony-ycor random-ycor
    create-turtles start-colony-turtle-cnt [
      setxy colony-xcor colony-ycor
      fd random 5
      set age random turtle-lifespan
      set energy (random-normal 18 0.9 )
      get-infant-knowledge
      set color turtle-colour
    ]
  ]
end

to go
  tick

  ask turtles [
    take-food
    if ((random energy) > reproduction-energy-min and age > reproduction-age-min) [
      give-birth
    ]
    set energy (energy - 1)
    move-somewhere
    set age (age + 1)
    live-or-die
    communicate
  ]

  ask patches [
    fill-patches-food-energy-value
    decay-existing-food
    update-patches
  ]

  ; Update plots every 8 ticks
  if (remainder ticks 8 = 0) [
    update-graphs
  ]
end


to take-food
  ; Calculate food bonus
  let food-bonus (map [ [i] -> ceiling (i * 20) ] food-knowledge-list)

  ; True value of tile to the turtle
  let tile-values (map [ [bonus food-count] -> ifelse-value (food-count > 0) [1 + bonus] [0] ] food-bonus foodCountList)
  let max-tile-value (max tile-values)

  ; Only take food if tile is worth something
  if (max-tile-value > 0) [
    let max-tile-value-idx (position max-tile-value tile-values)
    set energy (energy + (max-tile-value + food-base-energy-value))
    set foodCountList (replace-item max-tile-value-idx foodCountList ((item max-tile-value-idx foodCountList) - 1))
  ]
end

; Find the best turtle in range (learning-distance) and learn from it
to communicate
  let turtles-in-range-knowledge [food-knowledge-list] of (turtles in-radius learning-distance)
  if (length turtles-in-range-knowledge > 0) [
    let turtles-in-range-knowledge-rating map [[i] -> sum i] turtles-in-range-knowledge
    let best-rating max turtles-in-range-knowledge-rating

    let max-ratinge-idx (position best-rating turtles-in-range-knowledge-rating)
    let knowledge-of-best-turtle-in-range (item max-ratinge-idx turtles-in-range-knowledge)

    let communicated-knowledge (map [ [i] -> ( i - (random-float learning-rate) + ( learning-success-chance * learning-rate )) ] knowledge-of-best-turtle-in-range);

    set food-knowledge-list (map [ [old-knowledge better-knowledge] -> ((old-knowledge * learning-change-difficulty) + better-knowledge ) / (1 + learning-change-difficulty) ] food-knowledge-list communicated-knowledge);
  ]
end

to live-or-die
  if (energy < 0) or (age > turtle-lifespan) [ ; show word word energy " is energy, age is " age
    die
  ]
end


to give-birth
  hatch 1 [
    set age 0
    set energy (energy * 0.2)
    ; Born with knowledge
    get-infant-knowledge
  ]

  ; Parent pays the price
  set energy (energy * 0.8)
end


; "infant": for no particular reason except code efficiency, the agents learn at birth whatever they would individually discover in their lifetime
to get-infant-knowledge
  let ixi 0
  set food-knowledge-list (n-values num-food-types [0.1])
end


;;;;;;;;;;HOW TO MOVE;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Move somewhere in a random direction if hungry, towards the nearest population if not hungry
to move-somewhere
  ifelse (energy > swarming-energy and random-float 1.0 < swarming-probability) [
    let close-turtles (turtles in-radius swarming-distance)
    let delta-xcor (mean [xcor] of close-turtles) - xcor
    let delta-ycor (mean [ycor] of close-turtles) - ycor
    ifelse (delta-xcor = 0 and delta-ycor = 0) [
      rt random 360
    ] [
      set heading (atan delta-xcor delta-ycor) + random 50 - 25
    ]
  ] [
    rt random 360
  ]
  move-forward
end

to move-forward
  forward (gamma-flight turtle-move-speed)
end

; this is all from Edwards et al 2007 (more natural than Levy Flight) via Dr. Lowe
to-report gamma-flight [len]
  let half-len len / 2
  let gamma (len ^ 2) / 12
  let alpha (half-len ^ 2 ) / half-len
  let lambda half-len / gamma

  ;alpha and lambda are what netlogo calls its gamma parameters, but they don't document what they really are.
  ;alpha is really shape, and lambda is really rate.
  report (random-gamma alpha lambda)
end


;;;;;;;;;; DISPLAY ;;;;;;;;;;;;;;;;;;;;;;
;; every time the flip-button is pressed
;; the value of show-knowledge is incremented by one untill its greater then the
;; number of different things in the environment, then it is set back to 1
;; the value of show-knowledge corresponds to the turtles' knowledge-slots

to flip-color
  if (num-special-food-strat != 0) [
    set show-knowledge (show-knowledge + 1)
    if (show-knowledge > num-special-food-strat) [
      set show-knowledge 1
    ]
  ]
end

to knowledge-gradient
  set show-knowledge (num-special-food-strat + 42)
  ask turtles [
    update-looks-gradient
  ]
end

to update-looks-gradient
let k (sum food-knowledge-list)
set color ifelse-value (k = 0)[turtle-colour] [ifelse-value
                       (k = 1)[106] [ifelse-value
                       (k = 2)[116 ] [ifelse-value
                       (k = 3)[126] [ifelse-value
                       (k = 4)[136] ; k > 4
                              [9]]]]]
end

;to update-patches-food
;  set color (((only-one (item (show-knowledge - 1) (butfirst (herelist)))) * 10 * show-knowledge) + 14 )
;end

to color-off
  set show-knowledge 0
  set color turtle-colour
end



;;;;;;;;;;;;;;;UTILITIES, AUXILLARY REPORTERS AND PROCEDURES;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; some of these were used only in early analysis, might be fun for others.

;;takes 2 lists and outputs one list that is 'adjusted'
;;the list describing the food available at a certain patch is
;;adjusted according to the list describing turtle food-knowledge-list
;; assumes turtle ate everything it knew how to eat!
to-report adjust-foodCountList [hrlst knwhw]
  if hrlst = [] [
    report []
  ]
  ifelse (first knwhw = 1) [
    report (fput 0 (adjust-foodCountList (butfirst hrlst) (butfirst knwhw)))
  ] [
    report (fput (first hrlst) (adjust-foodCountList (butfirst hrlst) (butfirst knwhw)))
  ]
end

;; Adds value to food count up to max
to-report add-food [food-type food-list]
  let new-food-cnt (item food-type food-list) + food-grow-size
  set new-food-cnt ifelse-value (new-food-cnt > food-max) [food-max] [new-food-cnt]
  report (replace-item food-type food-list new-food-cnt)
end

;; Removes value of food count up to max
to-report remove-food [food-list]
  report ( map [[i] -> ifelse-value (i < 1) [0] [i - 1] ] food-list )
end

;;takes a list and returns the list of non-zero item-numbers
;n is the counter
to-report non-zero [l n]
  if l = [] [
    report []
  ]
  ifelse (first l = 1) [
    report fput n (non-zero butfirst l (n + 1))
  ] [
    report non-zero butfirst l (n + 1)
  ]
end


;;sum over lots of lists
to-report sum-list [lijst-van-lijsten]
  if (lijst-van-lijsten = []) [
    report []
  ]
  report sum2 (first lijst-van-lijsten) (sum-list (but-first lijst-van-lijsten))
end

;;sum over 2 lists
to-report sum2 [list1 list2]
  if (list2 = []) [
    report list1
  ]
  report (map [ [?1 ?2] -> ?1 + ?2 ] list1 list2)
end

to-report field
  report (world-width  * world-height)
end

;reports 1 if n > 0
to-report only-one [n]
  ifelse (n > 0) [
    report 1
  ] [
    report 0
  ]
end


;;;;;;;;;;;;;;;THE PLOTTING PART;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-graphs
  update-plot-all
end

to update-plot-all
  let c 0

;  locals [c r]
  set-current-plot "plot-all"
  set-current-plot-pen "turtles"
  plot count turtles
  set-current-plot-pen "reg-food"
  plot ceiling ( 0.2 * (sum (map sum ([foodCountList] of patches))))
  set-current-plot-pen "know"
  ifelse (count turtles != 0) [
    plot ceiling (avg-knowledge * 3000)
  ] [
    plot 0
  ]

end

to-report energy-turtles
  report mean ([energy] of turtles)
end

to-report avg-knowledge
  report mean [mean food-knowledge-list] of turtles
end

to-report safe-standard-deviation [lll]
  ifelse (length lll > 1) [
    report standard-deviation lll
  ] [
    report 0
  ]
end

to-report safe-mean [lll]
  ifelse (length lll > 0) [
    report mean lll
  ] [
    report 0
  ]
end

to-report avg-turtles-k [iii]
  report safe-mean [energy] of (turtles with [iii = sum food-knowledge-list])
end

to-report count-turtles-k [iii]
  report count turtles with [iii = sum food-knowledge-list]
end

to-report sd-turtles-k [iii]
  report safe-standard-deviation [energy] of (turtles with [iii = sum food-knowledge-list])
end

;plots the age of the turtles having offspring
to update-plot-offspring
  set-current-plot "offspring"
  set-current-plot-pen "age"
  set-plot-pen-mode 2
end

;plots number of turtles knowing 1-2-3 etc things, for each breed
to update-t-s-food-knowledge-list
  let s 0
  let t 0

  set-current-plot "t-s-food-knowledge-list"
  set-current-plot-pen "turtles"
  set-plot-pen-mode 1
  histogram [sum food-knowledge-list] of turtles
end


;plots number of turtles knowing 1-2-3 etc things, for each breed
to update-cost-of-speaking
  let iii 0

  set-current-plot "cost of speaking"
  set iii 0
  clear-plot
  while [iii < num-food-types] [
    set-current-plot-pen "turtles"
    ifelse (any? turtles with [iii = sum food-knowledge-list]) [
      plotxy iii mean [energy] of (turtles with [iii = sum food-knowledge-list])
    ] [
      plotxy iii 0
    ]
    set iii iii + 1
  ]
end


;plots number of turtles knowing 1-2-3 etc things, for each breed
to update-speaking-cost-over-time
  let iii 0
  let yyy 0

  set-current-plot "speaking cost over time"
  set iii 1
  while [iii < 6] [
    set-current-plot-pen word iii " things"
    set yyy energy-diff iii
    plot yyy
    set iii iii + 1
  ]
end

to-report energy-diff [sum-know-how]
  let sss 0
  let ttt 0

  ifelse (any? turtles with [sum-know-how = sum food-knowledge-list]) [
    set ttt mean [energy] of (turtles with [sum-know-how = sum food-knowledge-list])
  ] [
    set ttt 0
  ]
  report sss - ttt
end
@#$#@#$#@
GRAPHICS-WINDOW
546
10
1328
793
-1
-1
6.0
1
10
1
1
1
0
1
1
1
-64
64
-64
64
0
0
1
ticks
30.0

BUTTON
25
10
92
44
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
120
11
183
44
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
25
247
521
592
plot-all
NIL
NIL
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"turtles" 1.0 0 -13345367 true "" ""
"reg-food" 1.0 0 -2674135 true "" ""
"know" 1.0 0 -10899396 true "" ""

BUTTON
188
12
258
45
go 1x
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
26
142
354
175
food-replacement-rate
food-replacement-rate
0
0.05
0.02
.0025
1
% per cycle
HORIZONTAL

MONITOR
23
54
80
99
NIL
ticks
17
1
11

MONITOR
182
55
267
100
knowledge
avg-knowledge
4
1
11

MONITOR
84
54
177
99
NIL
count turtles
0
1
11

SLIDER
26
179
345
212
swarming-probability
swarming-probability
0
1.0
0.9
0.1
1
NIL
HORIZONTAL

BUTTON
261
13
360
46
record-sim
run-simulation-to-file
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This model starts from an existing model (by Cace & Bryson).  This model looks at the benefits of swarming within a population where knowledge is spread through proximity.

## HOW IT WORKS

life and death
When they run out of energy or reach the maximum age, the agents die. Turtles can begin to give birth when they reach a threshold age and energy level.

*communication
At every time-step a turtle learns from the most intelligent turtle around it that is within the communication distance. Offspring is born with the base knowledge required to survive. 

*feeding
When the turtles that know are at a patch with the food they know of, they get more energy.

*patches
The user defines the rate at which food is added to the environment. Every patch has the probability of (replace-rate/1.0) of being filled with food.

*the walkabout
The turtles walk around according to levi flight. Foraging animals and foraging optimised agents, regardsless of their implementation (genetic algorithms, NN) do the levi flight.
The probability of a step of lenghth l is P(l):
P(l) = 1/z * 1/l^mu
z is a normalizing constant.
mu is a value between 1 and 3. For this model i have taken 1/mu= 0.3.

The turns are just random unless the turtle is full, at which point it meanders to the most populated spot nearby.

## HOW TO USE IT

## SETUP_BUTTONS:

+ swarming-probabilty: change this to the desired value at the start of the simulation and run.

## RELATED MODELS

In 2007 JJB branched this model from the archival version of the FreeInfo model that was submitted to Nature in April 2007.  That model was derived from an early version of the model Ivana Cace used for her diploma / MSc dissertation at Utrecht.

## CREDITS AND REFERENCES

Environment:
The algorithm for putting food in the environment is taken from the Rabbits Grass Weeds model.
Copyright 1998 by Uri Wilensky.  All rights reserved.  See
; http://ccl.northwestern.edu/netlogo/models/RabbitsGrassWeeds
; for terms of use.

Levi-flight
see:
Universal Properties of Adaptive Behaviour
Michel van Dartel Eric Postma Jaap van den Herik
IKAT, Universiteit Maastricht, P.O. Box 616 6200 MD Maastricht

But the idea (mine and probably theirs too) comes from a talk at the BNAIS conference in Utrecht some years ago, 2001?
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

ant
true
0
Polygon -7500403 true true 136 61 129 46 144 30 119 45 124 60 114 82 97 37 132 10 93 36 111 84 127 105 172 105 189 84 208 35 171 11 202 35 204 37 186 82 177 60 180 44 159 32 170 44 165 60
Polygon -7500403 true true 150 95 135 103 139 117 125 149 137 180 135 196 150 204 166 195 161 180 174 150 158 116 164 102
Polygon -7500403 true true 149 186 128 197 114 232 134 270 149 282 166 270 185 232 171 195 149 186
Polygon -7500403 true true 225 66 230 107 159 122 161 127 234 111 236 106
Polygon -7500403 true true 78 58 99 116 139 123 137 128 95 119
Polygon -7500403 true true 48 103 90 147 129 147 130 151 86 151
Polygon -7500403 true true 65 224 92 171 134 160 135 164 95 175
Polygon -7500403 true true 235 222 210 170 163 162 161 166 208 174
Polygon -7500403 true true 249 107 211 147 168 147 168 150 213 150

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bee
true
0
Polygon -1184463 true false 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true false 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -7500403 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true false 70 185 74 171 223 172 224 186
Polygon -16777216 true false 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true false 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

bird1
false
0
Polygon -7500403 true true 2 6 2 39 270 298 297 298 299 271 187 160 279 75 276 22 100 67 31 0

bird2
false
0
Polygon -7500403 true true 2 4 33 4 298 270 298 298 272 298 155 184 117 289 61 295 61 105 0 43

boat1
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 33 230 157 182 150 169 151 157 156
Polygon -7500403 true true 149 55 88 143 103 139 111 136 117 139 126 145 130 147 139 147 146 146 149 55

boat2
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 157 54 175 79 174 96 185 102 178 112 194 124 196 131 190 139 192 146 211 151 216 154 157 154
Polygon -7500403 true true 150 74 146 91 139 99 143 114 141 123 137 126 131 129 132 139 142 136 126 142 119 147 148 147

boat3
false
0
Polygon -1 true false 63 162 90 207 223 207 290 162
Rectangle -6459832 true false 150 32 157 162
Polygon -13345367 true false 150 34 131 49 145 47 147 48 149 49
Polygon -7500403 true true 158 37 172 45 188 59 202 79 217 109 220 130 218 147 204 156 158 156 161 142 170 123 170 102 169 88 165 62
Polygon -7500403 true true 149 66 142 78 139 96 141 111 146 139 148 147 110 147 113 131 118 106 126 71

box
true
0
Polygon -7500403 true true 45 255 255 255 255 45 45 45

butterfly1
true
0
Polygon -16777216 true false 151 76 138 91 138 284 150 296 162 286 162 91
Polygon -7500403 true true 164 106 184 79 205 61 236 48 259 53 279 86 287 119 289 158 278 177 256 182 164 181
Polygon -7500403 true true 136 110 119 82 110 71 85 61 59 48 36 56 17 88 6 115 2 147 15 178 134 178
Polygon -7500403 true true 46 181 28 227 50 255 77 273 112 283 135 274 135 180
Polygon -7500403 true true 165 185 254 184 272 224 255 251 236 267 191 283 164 276
Line -7500403 true 167 47 159 82
Line -7500403 true 136 47 145 81
Circle -7500403 true true 165 45 8
Circle -7500403 true true 134 45 6
Circle -7500403 true true 133 44 7
Circle -7500403 true true 133 43 8

circle
false
0
Circle -7500403 true true 35 35 230

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

loud
false
15
Circle -1 true true 4 9 285
Rectangle -16777216 true false 118 46 179 246
Rectangle -1 true true 105 24 189 51
Rectangle -1 true true 105 31 196 56
Rectangle -1 true true 99 33 189 60
Rectangle -1 true true 108 193 205 205
Rectangle -1 true true 96 193 197 210
Rectangle -1 true true 174 38 201 267
Rectangle -1 true true 109 34 123 258
Rectangle -1 true true 102 26 125 246
Rectangle -1 true true 171 44 191 254
Rectangle -16777216 true false 125 36 170 80
Rectangle -16777216 true false 125 243 170 268
Rectangle -1 true true 104 195 193 218
Rectangle -1 true true 172 15 172 21
Rectangle -1 true true 169 29 192 276
Rectangle -1 true true 90 197 187 223
Rectangle -16777216 true false 125 219 168 229
Rectangle -16777216 true false 157 219 168 232
Rectangle -16777216 true false 158 219 169 241
Rectangle -16777216 true false 124 214 168 224
Rectangle -16777216 true false 160 214 171 215
Rectangle -16777216 true false 158 215 171 224
Rectangle -1 true true 168 195 188 227
Rectangle -16777216 true false 164 214 168 239
Rectangle -16777216 true false 164 216 172 228
Rectangle -16777216 true false 165 209 171 223
Rectangle -1 true true 169 202 185 241
Rectangle -1 true true 149 198 185 213
Rectangle -1 true true 159 203 175 213
Rectangle -1 true true 160 204 175 213
Rectangle -1 true true 159 207 176 214
Rectangle -1 true true 109 205 124 228
Rectangle -1 true true 116 200 124 229
Rectangle -1 true true 111 206 125 230

person
false
0
Circle -7500403 true true 155 20 63
Rectangle -7500403 true true 158 79 217 164
Polygon -7500403 true true 158 81 110 129 131 143 158 109 165 110
Polygon -7500403 true true 216 83 267 123 248 143 215 107
Polygon -7500403 true true 167 163 145 234 183 234 183 163
Polygon -7500403 true true 195 163 195 233 227 233 206 159

predator
true
0
Polygon -2064490 true false 270 255 225 180 105 180 45 255 135 285 165 285
Polygon -2064490 true false 165 135 165 75 270 60 225 120 165 165 165 135
Polygon -2064490 true false 135 135 135 75 30 60 75 120 135 165 135 135

sheep
false
15
Rectangle -1 true true 90 75 270 225
Circle -1 true true 15 75 150
Rectangle -16777216 true false 81 225 134 286
Rectangle -16777216 true false 180 225 238 285
Circle -16777216 true false 1 88 92

silent
false
15
Polygon -1 true true 69 6 4 64 200 278 275 210
Polygon -1 true true 79 276 17 216 203 7 276 67

spacecraft
true
0
Polygon -7500403 true true 150 0 180 135 255 255 225 240 150 180 75 240 45 255 120 135

thin-arrow
true
0
Polygon -7500403 true true 150 0 0 150 120 150 120 293 180 293 180 150 300 150

truck-down
false
0
Polygon -7500403 true true 225 30 225 270 120 270 105 210 60 180 45 30 105 60 105 30
Polygon -8630108 true false 195 75 195 120 240 120 240 75
Polygon -8630108 true false 195 225 195 180 240 180 240 225

truck-left
false
0
Polygon -7500403 true true 120 135 225 135 225 210 75 210 75 165 105 165
Polygon -8630108 true false 90 210 105 225 120 210
Polygon -8630108 true false 180 210 195 225 210 210

truck-right
false
0
Polygon -7500403 true true 180 135 75 135 75 210 225 210 225 165 195 165
Polygon -8630108 true false 210 210 195 225 180 210
Polygon -8630108 true false 120 210 105 225 90 210

turtle
true
0
Polygon -7500403 true true 138 75 162 75 165 105 225 105 225 142 195 135 195 187 225 195 225 225 195 217 195 202 105 202 105 217 75 225 75 195 105 187 105 135 75 142 75 105 135 105

wolf
false
0
Rectangle -7500403 true true 15 105 105 165
Rectangle -7500403 true true 45 90 105 105
Polygon -7500403 true true 60 90 83 44 104 90
Polygon -16777216 true false 67 90 82 59 97 89
Rectangle -1 true false 48 93 59 105
Rectangle -16777216 true false 51 96 55 101
Rectangle -16777216 true false 0 121 15 135
Rectangle -16777216 true false 15 136 60 151
Polygon -1 true false 15 136 23 149 31 136
Polygon -1 true false 30 151 37 136 43 151
Rectangle -7500403 true true 105 120 263 195
Rectangle -7500403 true true 108 195 259 201
Rectangle -7500403 true true 114 201 252 210
Rectangle -7500403 true true 120 210 243 214
Rectangle -7500403 true true 115 114 255 120
Rectangle -7500403 true true 128 108 248 114
Rectangle -7500403 true true 150 105 225 108
Rectangle -7500403 true true 132 214 155 270
Rectangle -7500403 true true 110 260 132 270
Rectangle -7500403 true true 210 214 232 270
Rectangle -7500403 true true 189 260 210 270
Line -7500403 true 263 127 281 155
Line -7500403 true 281 155 281 192

wolf-left
false
3
Polygon -6459832 true true 117 97 91 74 66 74 60 85 36 85 38 92 44 97 62 97 81 117 84 134 92 147 109 152 136 144 174 144 174 103 143 103 134 97
Polygon -6459832 true true 87 80 79 55 76 79
Polygon -6459832 true true 81 75 70 58 73 82
Polygon -6459832 true true 99 131 76 152 76 163 96 182 104 182 109 173 102 167 99 173 87 159 104 140
Polygon -6459832 true true 107 138 107 186 98 190 99 196 112 196 115 190
Polygon -6459832 true true 116 140 114 189 105 137
Rectangle -6459832 true true 109 150 114 192
Rectangle -6459832 true true 111 143 116 191
Polygon -6459832 true true 168 106 184 98 205 98 218 115 218 137 186 164 196 176 195 194 178 195 178 183 188 183 169 164 173 144
Polygon -6459832 true true 207 140 200 163 206 175 207 192 193 189 192 177 198 176 185 150
Polygon -6459832 true true 214 134 203 168 192 148
Polygon -6459832 true true 204 151 203 176 193 148
Polygon -6459832 true true 207 103 221 98 236 101 243 115 243 128 256 142 239 143 233 133 225 115 214 114

wolf-right
false
3
Polygon -6459832 true true 170 127 200 93 231 93 237 103 262 103 261 113 253 119 231 119 215 143 213 160 208 173 189 187 169 190 154 190 126 180 106 171 72 171 73 126 122 126 144 123 159 123
Polygon -6459832 true true 201 99 214 69 215 99
Polygon -6459832 true true 207 98 223 71 220 101
Polygon -6459832 true true 184 172 189 234 203 238 203 246 187 247 180 239 171 180
Polygon -6459832 true true 197 174 204 220 218 224 219 234 201 232 195 225 179 179
Polygon -6459832 true true 78 167 95 187 95 208 79 220 92 234 98 235 100 249 81 246 76 241 61 212 65 195 52 170 45 150 44 128 55 121 69 121 81 135
Polygon -6459832 true true 48 143 58 141
Polygon -6459832 true true 46 136 68 137
Polygon -6459832 true true 45 129 35 142 37 159 53 192 47 210 62 238 80 237
Line -16777216 false 74 237 59 213
Line -16777216 false 59 213 59 212
Line -16777216 false 58 211 67 192
Polygon -6459832 true true 38 138 66 149
Polygon -6459832 true true 46 128 33 120 21 118 11 123 3 138 5 160 13 178 9 192 0 199 20 196 25 179 24 161 25 148 45 140
Polygon -6459832 true true 67 122 96 126 63 144
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="HBES-selective-pressure" repetitions="32" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="16000"/>
    <metric>count talker</metric>
    <metric>count silent</metric>
    <enumeratedValueSet variable="simulation-runtime">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-depletes?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-proportion-altruists">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lifespan">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="travel-mode">
      <value value="&quot;smooth distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-replacement-rate">
      <value value="3.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-num-turtles">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freq-of-mutation">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ratio-of-special-foods">
      <value value="-3"/>
      <value value="-4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-dist">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="broadcast-radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-strat">
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HBES-indi-nomut" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="14000"/>
    <metric>count talker</metric>
    <metric>count silent</metric>
    <metric>safe-mean [sum knowhow] of talker</metric>
    <metric>safe-standard-deviation [sum knowhow] of talker</metric>
    <metric>safe-mean [sum knowhow] of silent</metric>
    <metric>safe-standard-deviation [sum knowhow] of silent</metric>
    <metric>avg-silent-k 1</metric>
    <metric>sd-silent-k 1</metric>
    <metric>count-silent-k 1</metric>
    <metric>avg-talker-k 1</metric>
    <metric>sd-talker-k 1</metric>
    <metric>count-talker-k 1</metric>
    <metric>avg-silent-k 2</metric>
    <metric>sd-silent-k 2</metric>
    <metric>count-silent-k 2</metric>
    <metric>avg-talker-k 2</metric>
    <metric>sd-talker-k 2</metric>
    <metric>count-talker-k 2</metric>
    <metric>avg-silent-k 3</metric>
    <metric>sd-silent-k 3</metric>
    <metric>count-silent-k 3</metric>
    <metric>avg-talker-k 3</metric>
    <metric>sd-talker-k 3</metric>
    <metric>count-talker-k 3</metric>
    <metric>avg-silent-k 4</metric>
    <metric>sd-silent-k 4</metric>
    <metric>count-silent-k 4</metric>
    <metric>avg-talker-k 4</metric>
    <metric>sd-talker-k 4</metric>
    <metric>count-talker-k 4</metric>
    <metric>avg-silent-k 5</metric>
    <metric>sd-silent-k 5</metric>
    <metric>count-silent-k 5</metric>
    <metric>avg-talker-k 5</metric>
    <metric>sd-talker-k 5</metric>
    <metric>count-talker-k 5</metric>
    <metric>avg-silent-k 6</metric>
    <metric>sd-silent-k 6</metric>
    <metric>count-silent-k 6</metric>
    <metric>avg-talker-k 6</metric>
    <metric>sd-talker-k 6</metric>
    <metric>count-talker-k 6</metric>
    <metric>avg-silent-k 7</metric>
    <metric>sd-silent-k 7</metric>
    <metric>count-silent-k 7</metric>
    <metric>avg-talker-k 7</metric>
    <metric>sd-talker-k 7</metric>
    <metric>count-talker-k 7</metric>
    <metric>avg-silent-k 8</metric>
    <metric>sd-silent-k 8</metric>
    <metric>count-silent-k 8</metric>
    <metric>avg-talker-k 8</metric>
    <metric>sd-talker-k 8</metric>
    <metric>count-talker-k 8</metric>
    <enumeratedValueSet variable="alert-bias">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-runtime">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-depletes?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-proportion-altruists">
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lifespan">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="travel-mode">
      <value value="&quot;smooth distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-replacement-rate">
      <value value="3.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-num-turtles">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freq-of-mutation">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ratio-of-special-foods">
      <value value="-3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-dist">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="broadcast-radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-strat">
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HBES-indi-mut40" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="14000"/>
    <metric>count talker</metric>
    <metric>count silent</metric>
    <metric>safe-mean [sum knowhow] of talker</metric>
    <metric>safe-standard-deviation [sum knowhow] of talker</metric>
    <metric>safe-mean [sum knowhow] of silent</metric>
    <metric>safe-standard-deviation [sum knowhow] of silent</metric>
    <metric>avg-silent-k 1</metric>
    <metric>sd-silent-k 1</metric>
    <metric>count-silent-k 1</metric>
    <metric>avg-talker-k 1</metric>
    <metric>sd-talker-k 1</metric>
    <metric>count-talker-k 1</metric>
    <metric>avg-silent-k 2</metric>
    <metric>sd-silent-k 2</metric>
    <metric>count-silent-k 2</metric>
    <metric>avg-talker-k 2</metric>
    <metric>sd-talker-k 2</metric>
    <metric>count-talker-k 2</metric>
    <metric>avg-silent-k 3</metric>
    <metric>sd-silent-k 3</metric>
    <metric>count-silent-k 3</metric>
    <metric>avg-talker-k 3</metric>
    <metric>sd-talker-k 3</metric>
    <metric>count-talker-k 3</metric>
    <metric>avg-silent-k 4</metric>
    <metric>sd-silent-k 4</metric>
    <metric>count-silent-k 4</metric>
    <metric>avg-talker-k 4</metric>
    <metric>sd-talker-k 4</metric>
    <metric>count-talker-k 4</metric>
    <metric>avg-silent-k 5</metric>
    <metric>sd-silent-k 5</metric>
    <metric>count-silent-k 5</metric>
    <metric>avg-talker-k 5</metric>
    <metric>sd-talker-k 5</metric>
    <metric>count-talker-k 5</metric>
    <metric>avg-silent-k 6</metric>
    <metric>sd-silent-k 6</metric>
    <metric>count-silent-k 6</metric>
    <metric>avg-talker-k 6</metric>
    <metric>sd-talker-k 6</metric>
    <metric>count-talker-k 6</metric>
    <metric>avg-silent-k 7</metric>
    <metric>sd-silent-k 7</metric>
    <metric>count-silent-k 7</metric>
    <metric>avg-talker-k 7</metric>
    <metric>sd-talker-k 7</metric>
    <metric>count-talker-k 7</metric>
    <metric>avg-silent-k 8</metric>
    <metric>sd-silent-k 8</metric>
    <metric>count-silent-k 8</metric>
    <metric>avg-talker-k 8</metric>
    <metric>sd-talker-k 8</metric>
    <metric>count-talker-k 8</metric>
    <enumeratedValueSet variable="simulation-runtime">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-depletes?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-proportion-altruists">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lifespan">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="travel-mode">
      <value value="&quot;smooth distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-replacement-rate">
      <value value="3.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-num-turtles">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freq-of-mutation">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ratio-of-special-foods">
      <value value="-3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-dist">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="broadcast-radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-strat">
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HBES-indi-mut50" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="14000"/>
    <metric>count talker</metric>
    <metric>count silent</metric>
    <metric>safe-mean [sum knowhow] of talker</metric>
    <metric>safe-standard-deviation [sum knowhow] of talker</metric>
    <metric>safe-mean [sum knowhow] of silent</metric>
    <metric>safe-standard-deviation [sum knowhow] of silent</metric>
    <metric>avg-silent-k 1</metric>
    <metric>sd-silent-k 1</metric>
    <metric>count-silent-k 1</metric>
    <metric>avg-talker-k 1</metric>
    <metric>sd-talker-k 1</metric>
    <metric>count-talker-k 1</metric>
    <metric>avg-silent-k 2</metric>
    <metric>sd-silent-k 2</metric>
    <metric>count-silent-k 2</metric>
    <metric>avg-talker-k 2</metric>
    <metric>sd-talker-k 2</metric>
    <metric>count-talker-k 2</metric>
    <metric>avg-silent-k 3</metric>
    <metric>sd-silent-k 3</metric>
    <metric>count-silent-k 3</metric>
    <metric>avg-talker-k 3</metric>
    <metric>sd-talker-k 3</metric>
    <metric>count-talker-k 3</metric>
    <metric>avg-silent-k 4</metric>
    <metric>sd-silent-k 4</metric>
    <metric>count-silent-k 4</metric>
    <metric>avg-talker-k 4</metric>
    <metric>sd-talker-k 4</metric>
    <metric>count-talker-k 4</metric>
    <metric>avg-silent-k 5</metric>
    <metric>sd-silent-k 5</metric>
    <metric>count-silent-k 5</metric>
    <metric>avg-talker-k 5</metric>
    <metric>sd-talker-k 5</metric>
    <metric>count-talker-k 5</metric>
    <metric>avg-silent-k 6</metric>
    <metric>sd-silent-k 6</metric>
    <metric>count-silent-k 6</metric>
    <metric>avg-talker-k 6</metric>
    <metric>sd-talker-k 6</metric>
    <metric>count-talker-k 6</metric>
    <metric>avg-silent-k 7</metric>
    <metric>sd-silent-k 7</metric>
    <metric>count-silent-k 7</metric>
    <metric>avg-talker-k 7</metric>
    <metric>sd-talker-k 7</metric>
    <metric>count-talker-k 7</metric>
    <metric>avg-silent-k 8</metric>
    <metric>sd-silent-k 8</metric>
    <metric>count-silent-k 8</metric>
    <metric>avg-talker-k 8</metric>
    <metric>sd-talker-k 8</metric>
    <metric>count-talker-k 8</metric>
    <enumeratedValueSet variable="simulation-runtime">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-depletes?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-proportion-altruists">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lifespan">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="travel-mode">
      <value value="&quot;smooth distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-replacement-rate">
      <value value="3.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-num-turtles">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freq-of-mutation">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ratio-of-special-foods">
      <value value="-3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-dist">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="broadcast-radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-strat">
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ACS-broadcast-vs-run" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="12000"/>
    <metric>count talker</metric>
    <metric>count silent</metric>
    <enumeratedValueSet variable="start-num-turtles">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freq-of-mutation">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-dist">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ratio-of-special-foods">
      <value value="-2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-strat">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-depletes?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lifespan">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-replacement-rate">
      <value value="3.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="travel-mode">
      <value value="&quot;levi flight&quot;"/>
      <value value="&quot;smooth distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="simulation-runtime">
      <value value="17000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="broadcast-radius">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-proportion-altruists">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="HBES-indi-test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1400"/>
    <metric>count talker</metric>
    <metric>count silent</metric>
    <metric>safe-mean [sum knowhow] of talker</metric>
    <metric>safe-standard-deviation [sum knowhow] of talker</metric>
    <metric>safe-mean [sum knowhow] of silent</metric>
    <metric>safe-standard-deviation [sum knowhow] of silent</metric>
    <metric>avg-silent-k 1</metric>
    <metric>sd-silent-k 1</metric>
    <metric>count-silent-k 1</metric>
    <metric>avg-talker-k 1</metric>
    <metric>sd-talker-k 1</metric>
    <metric>count-talker-k 1</metric>
    <metric>avg-silent-k 2</metric>
    <metric>sd-silent-k 2</metric>
    <metric>count-silent-k 2</metric>
    <metric>avg-talker-k 2</metric>
    <metric>sd-talker-k 2</metric>
    <metric>count-talker-k 2</metric>
    <metric>avg-silent-k 3</metric>
    <metric>sd-silent-k 3</metric>
    <metric>count-silent-k 3</metric>
    <metric>avg-talker-k 3</metric>
    <metric>sd-talker-k 3</metric>
    <metric>count-talker-k 3</metric>
    <metric>avg-silent-k 4</metric>
    <metric>sd-silent-k 4</metric>
    <metric>count-silent-k 4</metric>
    <metric>avg-talker-k 4</metric>
    <metric>sd-talker-k 4</metric>
    <metric>count-talker-k 4</metric>
    <metric>avg-silent-k 5</metric>
    <metric>sd-silent-k 5</metric>
    <metric>count-silent-k 5</metric>
    <metric>avg-talker-k 5</metric>
    <metric>sd-talker-k 5</metric>
    <metric>count-talker-k 5</metric>
    <metric>avg-silent-k 6</metric>
    <metric>sd-silent-k 6</metric>
    <metric>count-silent-k 6</metric>
    <metric>avg-talker-k 6</metric>
    <metric>sd-talker-k 6</metric>
    <metric>count-talker-k 6</metric>
    <metric>avg-silent-k 7</metric>
    <metric>sd-silent-k 7</metric>
    <metric>count-silent-k 7</metric>
    <metric>avg-talker-k 7</metric>
    <metric>sd-talker-k 7</metric>
    <metric>count-talker-k 7</metric>
    <metric>avg-silent-k 8</metric>
    <metric>sd-silent-k 8</metric>
    <metric>count-silent-k 8</metric>
    <metric>avg-talker-k 8</metric>
    <metric>sd-talker-k 8</metric>
    <metric>count-talker-k 8</metric>
    <enumeratedValueSet variable="simulation-runtime">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-depletes?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-proportion-altruists">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lifespan">
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="travel-mode">
      <value value="&quot;smooth distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-replacement-rate">
      <value value="3.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mutation?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="start-num-turtles">
      <value value="750"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freq-of-mutation">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ratio-of-special-foods">
      <value value="-3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="run-dist">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="broadcast-radius">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-food-strat">
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
