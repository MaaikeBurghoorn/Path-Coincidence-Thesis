globals [ border pheromone-visible? popularity-visible? ants-visible? food-visible? walkers-visible? shape-of-ants buildings ]
breed [ ants ant ]
breed [ food food-pellet ]
breed [ walkers walker ]

patches-own [ pheromone pheromone-dropped food-here? popularity R G B ]
ants-own [ my-pheromone-deposit-rate ]
walkers-own [ goal ]

;#################################
;########SETUP BOTH MODELS########
;#################################

to setup
  __clear-all-and-reset-ticks
  ;Slime mold code
  set-global-variables
  clear-all-patches
  add-ants nr-of-ants
  
  set buildings (list)
  
  ifelse withNodes [
    add-food nr-of-food-pellets 
    add-buildings 
    ] [ bless-ants ]
  ;;;;;;;;;;;;;;;;;;;;;;;
  
  ask patches [
    set R 0
    set G 0
    set B 0
    set popularity 1
  ]
  create-walkers walker-count [
    set xcor random-xcor
    set ycor random-ycor
    set goal one-of patches
    set color blue
    set size 5
  ]
end

to set-global-variables
  set ants-visible?      true
  set food-visible?      true
  set walkers-visible?   true
  set pheromone-visible? true
  set popularity-visible? true
  set shape-of-ants     "circle"

;Circle border
  set border patches with [
    distancexy 0 0 > (max-pxcor - 1)
  ] 
end

to clear-all-patches
  ask patches [ set pheromone 0 set pheromone-dropped 0 set food-here? false ]
end

to add-ants [ n ]
  create-ants n [
    set color orange
    set shape shape-of-ants
    set size 2.5
    if-else start-dispersed? [
      setxy random-xcor random-ycor
    ] [
      setxy 0 0
    ]
    set my-pheromone-deposit-rate ifelse-value pre-blessed? [ pheromone-deposit-rate ] [ 0 ]
  ]
end

to add-food [ n ]
  create-food n [
    set color yellow set shape "food"
    set size 2 * radius-of-food-pellets
    fd max-pxcor * random-float 0.8 ;Sets food further from center
  ]
  ; now separate
  let busy? true
  while [ busy? ] [
    set busy? false 
    ask food [
      let too-close min-one-of other food in-radius (7 * radius-of-food-pellets) [ distance myself ]
      if too-close != nobody [ face too-close fd random-float -7.0 set busy? true ]
    ]
  ]
  ask food [ 
    make-food-spot-here
    ;Buildings have the same location as foodpellets
    set buildings (fput patch-here buildings) 
    ]
end     

;##############################
;########GO BOTH MODELS########
;##############################

to go
  ;Update slime mold
  ask ants [ sense move ]
  manage-patches
  
  ;Update paths
  check-building-placement
  move-walkers
  decay-popularity
  
  tick
end

;##################################
;########PATH SPECIFIC CODE########
;##################################

to add-buildings
  ;Create buildings on setup at same location as food
  foreach buildings [ask ?1 [ set R 255 ] ]
end

to check-building-placement
  if mouse-down?
  [ask patch (round mouse-xcor) (round mouse-ycor) [
    ifelse R = 255
    [ unbecome-building ]
    [ become-building ]
  ]]
end

to unbecome-building
  set R 0
  set popularity 1
  set buildings (remove self buildings)
end

to become-building
  set R 255
  set buildings (fput self buildings)
end

to decay-popularity
  ask patches with [R != 255] [
    if popularity > 1 and not any? turtles-here [ set popularity popularity * (100 - popularity-decay-rate) / 100 ]
    ifelse B = 0
    [ if popularity < 1 [ set popularity 1 ] ]
    [ if popularity < 1 [
        set popularity 1
        set B 0
        if popularity-visible? [ set pcolor rgb R G B ]
        ] ]
  ]
end

to become-more-popular
  set popularity popularity + popularity-per-step
  if popularity > minimum-route-popularity [ set B 255 if popularity-visible? [ set pcolor rgb R G B ] ]
end

to move-walkers
  ask walkers [
    ifelse patch-here = goal
      [ ifelse length buildings >= 2
        [set goal one-of buildings]
        [set goal one-of patches] ]
      [ walk-towards-goal ] ]
end

to walk-towards-goal
  let last-distance distance goal
  let best-route-tile route-on-the-way-to goal last-distance

  ; boost the popularity of the route we're using
  if B = 0
  [ ask patch-here [become-more-popular] ]

  ifelse best-route-tile = nobody
  [ face goal ]
  [ face best-route-tile ]
  fd 1
end

to-report route-on-the-way-to [l current-distance]
  let routes-on-the-way-to-goal (patches in-radius walker-vision-dist with [
      B = 255 and distance l < current-distance - 1
    ])
  report min-one-of routes-on-the-way-to-goal [distance self]
end

;########################################
;########SLIME MOLD SPECIFIC CODE########
;########################################

to manage-patches
  diffuse pheromone diffusion-rate
  ask patches [
    set pheromone evaporation-rate * (pheromone + pheromone-dropped)
    set pheromone-dropped 0
    let normalized-value (pheromone / pheromone-factor-at-food) * 255
    set G normalized-value
    if pheromone-visible? [
      ifelse popularity-visible? 
      [ set pcolor rgb R G B ]
      [ set pcolor rgb R G 0 ]
    ] 
  ]
  if suck-pheromone-from-border [ ask border [ set pheromone 0 ] ]
end

;Set new ant direction
to sense ; execute sensory stage
  if random-float 1.0 < probability-of-death [ die ] ; live or die
  ;this code only makes sense if sensor-width > 1
  ;let FF sum [ pheromone ] of [ patches in-radius sensor-width ] of patch-ahead                        sensor-offset
  ;let FL sum [ pheromone ] of [ patches in-radius sensor-width ] of patch-left-and-ahead  sensor-angle sensor-offset
  ;let FR sum [ pheromone ] of [ patches in-radius sensor-width ] of patch-right-and-ahead sensor-angle sensor-offset 
  let FF [ pheromone ] of patch-ahead                        sensor-offset
  let FL [ pheromone ] of patch-left-and-ahead  sensor-angle sensor-offset
  let FR [ pheromone ] of patch-right-and-ahead sensor-angle sensor-offset 
  if FF > FL and FF > FR [ stop ]
  ;If both bigger, turn left or right at random
  if FF < FL and FF < FR [ right (random-polarity * rotation-angle) stop ]
  if FL < FR [ right rotation-angle stop ]
  if FR < FL [ left  rotation-angle stop ]
  ; else continue facing same direction
end


to move ; execute motor stage
  ; if co-location is allowed or goal patch is not occupied
  if-else co-location-allowed or not any? ants-on patch-ahead ant-step-size [
    fd ant-step-size ; forward and deposit pheromone
    if-else food-here? [
      ; a blessed ant is entitled to drop pheromone > 0
      bless
      ; drop "pheromone-factor-at-food" as many pheromone as usual
      set pheromone-dropped pheromone-dropped + my-pheromone-deposit-rate * pheromone-factor-at-food
    ] [
      ; beware: value "my-pheromone-deposit-rate" may be zero because ant may not
      ; have encountered food yet, hence may not be blessed; if not blessed let ant
      ; drop pheromone anyway, because then "my-pheromone-deposit-rate" is zero.
      set pheromone-dropped pheromone-dropped + my-pheromone-deposit-rate
    ]
  ] [
    ; if no co-location allowed and cannot move, then choose a random new orientation
    set heading random-float 360
  ]
end

to set-scenario-1
  ; food
  set nr-of-food-pellets 7
  set radius-of-food-pellets 4
  ; pheromone 
  set pheromone-visible? true
  set pheromone-deposit-rate 50
  set evaporation-rate 0.90
  set diffusion-rate 0.05
  set pheromone-factor-at-food 500
  ; ants
  set shape-of-ants "circle"
  set nr-of-ants 1000
  set ant-step-size 3.0
  set rotation-angle 45
  set sensor-offset 10
  set sensor-angle 45
  ; set sensor-width 2.0
  set pre-blessed? false
  set co-location-allowed false
end

to set-scenario-2
  set-scenario-1
  hide-ants
  remove-all-food
  set nr-of-food-pellets 0
  set pre-blessed? true
  set rotation-angle 45
  set sensor-offset 5
  set sensor-angle 45
end

to set-scenario-3
  set-scenario-2
  set rotation-angle 60
  set sensor-angle 60
end

to set-scenario-4
  set-scenario-2
  set rotation-angle 85
  set sensor-angle 85
end

; -- everything below this line does not involve the algorithmics of slime mould simulation

;########################################
;###############TOGGLES##################
;########################################

to toggle-walkers
  ask walkers [ set hidden? walkers-visible? ]
  set walkers-visible? not walkers-visible?
end

to toggle-food
  ask food [ set hidden? food-visible? ]
  set food-visible? not food-visible?
end

to toggle-ants
  ask ants [ set hidden? ants-visible? ]
  set ants-visible? not ants-visible?
end

to hide-ants
  ask ants [ set hidden? true ]
  set ants-visible? false
end

to toggle-popularity
  if popularity-visible? [
    ifelse pheromone-visible? 
    [ ask patches [ set pcolor rgb R G 0 ] ]
    [ ask patches [ set pcolor rgb R 0 0 ] ]
  ]
  set popularity-visible? not popularity-visible?
end

to toggle-pheromone
  if pheromone-visible? [ 
    ifelse popularity-visible?
    [ ask patches [ set pcolor rgb R 0 B ] ]
    [ ask patches [ set pcolor rgb R 0 0 ] ]
  ]
  set pheromone-visible? not pheromone-visible?
end

to bless-ants
  ask ants [ bless ]
end

to bless ; basically means: entitled to drop pheromone from now on
  set my-pheromone-deposit-rate pheromone-deposit-rate
end

to disperse-ants
  ask ants [
    setxy random-xcor random-ycor
    set heading random-float 360
  ]
end

to clear-patches-and-disperse-ants
  clear-all-patches
  disperse-ants
end

to toggle-ant-shape
  if-else shape-of-ants = "circle" [
    set shape-of-ants "Paramecium"
    ask ants [ set size 5.0 set shape shape-of-ants ]
  ] [
    set shape-of-ants "circle"
    ask ants [ set size 2.5 set shape shape-of-ants ]
  ]
end

to make-food-spot-here
  ask patches in-radius radius-of-food-pellets [
    set pheromone pheromone-factor-at-food * pheromone-deposit-rate
    set food-here? true
    if pheromone-visible? [ 
    let normalized-value (pheromone / pheromone-factor-at-food) * 255
    set G  normalized-value
    if pheromone-visible? [ set pcolor rgb R G B ]
    ]
  ]
end

to clear-food-spot-here
  ask patches in-radius radius-of-food-pellets [
    set pheromone 0
    set food-here? false
    if pheromone-visible? [ 
    let normalized-value (pheromone / pheromone-factor-at-food) * 255
    set G normalized-value
    if pheromone-visible? [ set pcolor rgb R G B ]
    ]
  ]
end

to insert-food
  if mouse-down? [
    ask min-one-of food [ distancexy mouse-xcor mouse-ycor ] [
      if distancexy mouse-xcor mouse-ycor > radius-of-food-pellets [
        hatch 1 [
          setxy mouse-xcor mouse-ycor
          make-food-spot-here
        ]
      ]
    ]
    display
  ]
end

to move-food
  if mouse-down? [
    ask min-one-of food [ distancexy mouse-xcor mouse-ycor ] [
      clear-food-spot-here
      setxy mouse-xcor mouse-ycor
      make-food-spot-here
    ]
    display
  ]
end

to remove-food
  if mouse-down? [
    ask food with [ distancexy mouse-xcor mouse-ycor <= radius-of-food-pellets ] [
      clear-food-spot-here die
    ]
    display
  ]
end

to remove-all-food
  ask food [ clear-food-spot-here die ] display
end

to move-ants-to-empty-food
  ask n-of 10 ants [
    move-to min-one-of food [ count ants in-radius radius-of-food-pellets ]
  ]
end

to spray-pheromone
  if mouse-down? [
    ask patch mouse-xcor mouse-ycor [
       ask patches in-radius radius-of-food-pellets [
         set pheromone pheromone + spray-factor * pheromone-deposit-rate
         if pheromone-visible? [ 
         let normalized-value (pheromone / pheromone-factor-at-food) * 255
         set G normalized-value
         if pheromone-visible? [ set pcolor rgb R G B ]
         ]
       ]
    ]
    display
  ]
end

to set-scenario
  ; clear-all
  reset-ticks
  run (word "set-scenario-" scenario-nr)
end

to show-border
  ask border [ set pcolor red ]
end

;Used to give ant random direction
to-report random-polarity
  report (2 * random 2) - 1
end


;########################################
;############CALCULATIONS################
;########################################

;Calculate sum-product of patches
;Illustrates coincidende between pheromone and popularity
to-report calcoverlap
  let total 0
  ask patches [
    set total total + pheromone * popularity
  ]
  report total / count patches
end
@#$#@#$#@
GRAPHICS-WINDOW
404
10
896
523
120
120
2.0
1
10
1
1
1
0
1
1
1
-120
120
-120
120
1
1
1
ticks
30.0

SLIDER
16
115
208
148
nr-of-ants
nr-of-ants
0
10000
1000
100
1
NIL
HORIZONTAL

BUTTON
17
10
113
43
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
115
10
208
43
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

SLIDER
17
359
208
392
rotation-angle
rotation-angle
0
180
60
5
1
NIL
HORIZONTAL

SLIDER
16
255
208
288
ant-step-size
ant-step-size
0
4
3
0.25
1
NIL
HORIZONTAL

SLIDER
17
324
208
357
sensor-angle
sensor-angle
0
120
60
5
1
NIL
HORIZONTAL

SLIDER
17
290
208
323
sensor-offset
sensor-offset
0
100
10
1
1
NIL
HORIZONTAL

SLIDER
208
325
400
358
evaporation-rate
evaporation-rate
0.85
1
0.9
0.01
1
NIL
HORIZONTAL

SLIDER
208
290
400
323
pheromone-deposit-rate
pheromone-deposit-rate
0
100
50
1
1
NIL
HORIZONTAL

SLIDER
208
360
400
393
diffusion-rate
diffusion-rate
0
0.5
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
208
80
400
113
nr-of-food-pellets
nr-of-food-pellets
0
100
7
1
1
NIL
HORIZONTAL

SLIDER
208
115
400
148
radius-of-food-pellets
radius-of-food-pellets
0.5
10
4
0.5
1
NIL
HORIZONTAL

SWITCH
17
394
208
427
co-location-allowed
co-location-allowed
1
1
-1000

BUTTON
310
150
400
183
NIL
move-food
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
208
10
284
43
NIL
toggle-ants
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
289
45
400
78
NIL
toggle-pheromone
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
208
45
287
78
NIL
toggle-food
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
286
10
400
43
NIL
toggle-ant-shape
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
208
430
400
463
pheromone-contrast
pheromone-contrast
0
100
34
1
1
NIL
HORIZONTAL

BUTTON
208
150
308
183
NIL
insert-food
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
208
185
321
218
NIL
remove-food
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
122
429
208
462
NIL
disperse-ants
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
208
465
400
498
NIL
spray-pheromone
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
17
45
72
78
set
set-scenario
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
74
45
208
78
scenario-nr
scenario-nr
1
4
1
1
1
NIL
HORIZONTAL

SLIDER
208
500
400
533
spray-factor
spray-factor
-0.1
0.1
-0.1
0.01
1
NIL
HORIZONTAL

SLIDER
208
395
400
428
pheromone-factor-at-food
pheromone-factor-at-food
0
1000
100
10
1
NIL
HORIZONTAL

BUTTON
17
429
123
462
clear-patches
clear-all-patches
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
208
255
400
288
NIL
move-ants-to-empty-food
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
323
185
400
218
remove-all
remove-all-food
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
17
464
208
497
NIL
clear-patches-and-disperse-ants
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
208
220
284
253
NIL
bless-ants
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
16
80
208
113
NIL
add-ants nr-of-ants
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
286
220
400
253
pre-blessed?
pre-blessed?
1
1
-1000

SWITCH
16
150
208
183
start-dispersed?
start-dispersed?
0
1
-1000

SLIDER
16
220
208
253
probability-of-death
probability-of-death
0
0.001
4.1E-4
0.00001
1
NIL
HORIZONTAL

SWITCH
16
185
208
218
suck-pheromone-from-border
suck-pheromone-from-border
1
1
-1000

SLIDER
899
35
1086
68
popularity-decay-rate
popularity-decay-rate
0
100
4
1
1
NIL
HORIZONTAL

SLIDER
899
70
1086
103
popularity-per-step
popularity-per-step
0
100
20
1
1
NIL
HORIZONTAL

SLIDER
899
105
1086
138
minimum-route-popularity
minimum-route-popularity
0
100
50
1
1
NIL
HORIZONTAL

SLIDER
899
140
1086
173
walker-count
walker-count
0
1000
500
1
1
NIL
HORIZONTAL

SLIDER
899
175
1086
208
walker-vision-dist
walker-vision-dist
0
30
10
1
1
NIL
HORIZONTAL

TEXTBOX
901
18
1051
36
PATHS OPTIONS
11
0.0
1

BUTTON
900
213
1012
246
NIL
toggle-walkers
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
900
247
1012
280
NIL
toggle-popularity
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1095
331
1258
376
Coincidence
calcoverlap
5
1
11

PLOT
1095
10
1828
329
Coincidence Overtime
Ticks
Coincidence
0.0
200.0
0.0
10.0
true
false
"plotxy ticks calcoverlap" ""
PENS
"pen-1" 1.0 0 -2674135 true "" "plot calcoverlap"

SWITCH
18
499
131
532
withNodes
withNodes
0
1
-1000

@#$#@#$#@
## Models

Paths model as presented by (Grider, 2015).
Available at: http://ccl.northwestern.edu/netlogo/models/Paths

Physarum model as presented by (Jones, 2011).
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cloud
false
0
Circle -7500403 true true 13 118 94
Circle -7500403 true true 86 101 127
Circle -7500403 true true 51 51 108
Circle -7500403 true true 118 43 95
Circle -7500403 true true 158 68 134

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

food
true
0
Polygon -7500403 true true 150 15 75 15 15 60 -15 135 30 195 45 270 135 300 195 270 270 255 285 180 300 120 255 75 210 0

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

paramecium
true
0
Polygon -7500403 true true 178 269 147 287 119 271 106 217 107 163 91 118 86 78 105 30 150 3 181 28 195 66 196 103 183 154 187 225
Line -7500403 true 85 22 109 32
Line -7500403 true 60 80 90 78
Line -7500403 true 179 156 209 159
Line -7500403 true 171 269 200 278
Line -7500403 true 92 279 123 269
Line -7500403 true 183 223 217 230
Line -7500403 true 192 104 226 107
Line -7500403 true 63 119 91 114
Line -7500403 true 83 216 113 214
Line -7500403 true 79 165 109 163
Line -7500403 true 175 27 205 25
Line -7500403 true 190 65 220 63

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Experiment 1 - Coincidence" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>let time remove ":" remove "." remove " " date-and-time

export-view (word "c:/users/maaike/skydrive/uu/ki/jaar 3/scriptie/resultaten/run 1/results" time ".png")</final>
    <exitCondition>ticks = 1000</exitCondition>
    <metric>calcoverlap</metric>
    <enumeratedValueSet variable="withNodes">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sensor-angle">
      <value value="20"/>
      <value value="45"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rotation-angle">
      <value value="20"/>
      <value value="45"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="suck-pheromone-from-border">
      <value value="true"/>
      <value value="false"/>
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
