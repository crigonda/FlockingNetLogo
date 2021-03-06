turtles-own [
  xRepulsion         ;; x component of the repulsion force
  yRepulsion         ;; y component of the repulsion force
  xAlignment         ;; x component of the alignment force
  yAlignment         ;; y component of the alignment force
  xCohesion          ;; x component of the cohesion force
  yCohesion          ;; y component of the cohesion force
  xPickUp            ;; x component of the object attraction force
  yPickUp            ;; y component of the object attraction force
  xSort              ;; x component of the "sort" force
  ySort              ;; y component of the "sort" force
  intensity          ;; Intensity of the total force
]

globals [
  defaultPatchColor  ;; Default color of the patches
  colorType1         ;; Color of the created objects with type 1
  colorType2         ;; Color of the created objects with type 2
  colorType3         ;; Color of the created objects with type 3
  colorType4         ;; Color of the created objects with type 4
  removedObjects     ;; Number of objects cleaned/picked-up
  performance ;; Number of agents without flockmates from the beginning of the simulation
]

to setColorTypes
  set colorType1 red
  set colorType2 lime
  set colorType3 blue
  set colorType4 pink
end

to setup
  clear-all
  set minSpeed 0.5
  set removedObjects 0
  create-turtles population
    [ set color yellow - 2 + random 7  ;; random shades look nice
      set size 1.5                     ;; easier to see
      set shape agentShape             ;; shapes of the turtles
      setxy random-xcor random-ycor
    ]
  ask patches [set pcolor black]
  setColorTypes ;; Sets color of the created objects according to their type
  reset-ticks
end

to go
  ask turtles [
    flock
    pickUpObject
  ]
  ;; WITH smooth movement animation
  repeat 5 [ ask turtles [ fd (intensity / 5) ] display ]
  ;; WITHOUT smooth animation (more efficient)
  ;; ask turtles [ fd 1 ]
  ;; Creation of objects
  createObjects
  ;; Performance measure
  performanceMeasure
  ;; Stops the simulation if ticks limit has been reached
  if (limitSimulation and ticks > tickNumber) [stop]
  tick
end

to flock  ;; turtle procedure
  let neighbours find-flockmates
  ifelse any? neighbours [applyForces neighbours]
  [wander]
end

to wander ;; turtle procedure
  set intensity minSpeed
end

;; ======================================================================

;;; FORCE COMPUTATION

to repulsionForce [neighbours] ;; turtle procedure
  ;; Position of the current turtle
  let xTurtle xcor
  let yTurtle ycor
  let currentTurtle self
  set xRepulsion sum [(1 / (distance currentTurtle + 0.1)) * (xTurtle - xcor)] of neighbours
  set yRepulsion sum [(1 / (distance currentTurtle + 0.1)) * (yTurtle - ycor)] of neighbours
end

to alignmentForce [neighbours] ;; turtle procedure
  set xAlignment mean [dx] of neighbours
  set yAlignment mean [dy] of neighbours
end

to cohesionForce [neighbours] ;; turtle procedure
  ;; The gravity center of all the neighbours
  let xGravity mean [xcor] of neighbours
  let yGravity mean [ycor] of neighbours
  ;; Computes the cohesion vector
  set xCohesion (xGravity - xcor)
  set yCohesion (yGravity - ycor)
end

to pickUpForce [objectives] ;; turtle procedure
  ;; The agent is attracted by the closest object
  ifelse any? objectives [
    let objective min-one-of objectives [distance myself]
    ;; Computes the attraction vector exerted by the object
    set xPickUp ([pxcor] of objective - xcor)
    set yPickUp ([pycor] of objective - ycor)
  ] [
    set xPickUp 0
    set yPickUp 0
  ]
end

to sortForce [nonFlockmates] ;; turtle procedure
  ;; ====================================================================
  ;; The sort force is divided into three components. It is exerted only
  ;; by the agents bearing a different type of object :
  ;;  - Opposite of the cohesion force
  ;;  - Opposite of the alignment force
  ;;  - "Another" repulsion force
  ;; The two first components are here to cancel the effect of the basic
  ;; alignment and cohesion forcest. The third component is here to force
  ;; an agent to leave a flock where it does not belong.
  ;; ====================================================================
  ifelse any? nonFlockmates [
    let xTurtle xcor
    let yTurtle ycor
    ;; Opposite of cohesion force
    let xGravity mean [xcor] of nonFlockmates
    let yGravity mean [ycor] of nonFlockmates
    set xSort (xTurtle - xGravity)
    set ySort (yTurtle - yGravity)
    ;; Opposite of alignment force
    let x-component mean [dx] of nonFlockmates
    let y-component mean [dy] of nonFlockmates
    set xSort (xSort - x-component)
    set ySort (ySort - y-component)
    ;; Repulsion force
    if repulsionSortActivated [
      let currentTurtle self
      set x-component sum [(1 / (distance currentTurtle + 0.1)) * (xTurtle - xcor)] of nonFlockmates
      set y-component sum [(1 / (distance currentTurtle + 0.1)) * (yTurtle - ycor)] of nonFlockmates
      set xSort (xSort + x-component / sqrt (x-component ^ 2 + y-component ^ 2))
      set ySort (ySort + y-component / sqrt (x-component ^ 2 + y-component ^ 2))
    ]
  ] [
    set xSort 0
    set ySort 0
  ]
end

;; ======================================================================

;; FORCES APPLICATION

to applyForces [neighbours] ;; turtle procedure
  repulsionForce neighbours
  alignmentForce neighbours
  cohesionForce neighbours
  pickUpForce find-objectives
  sortForce find-nonFlockmates
  ;; Sum of the 3 vectors (plus the pick up force)
  let xTotal (repulsionFactor * xRepulsion + alignmentFactor * xAlignment + cohesionFactor * xCohesion + pickUpFactor * xPickUp + sortFactor * xSort)
  let yTotal (repulsionFactor * yRepulsion + alignmentFactor * yAlignment + cohesionFactor * yCohesion + pickUpFactor * yPickUp + sortFactor * ySort)
  ;; Computes the direction and the norm of the vector
  let norm (sqrt (xTotal ^ 2 + yTotal ^ 2))
  if (xTotal != 0 or yTotal != 0) [
    smoothTurn (atan xTotal yTotal)
  ]
  ;; Make the turtle move in the right direction
  if norm > maxSpeed
  [set norm maxSpeed]
  if norm < minSpeed
  [set norm minSpeed]
  set intensity norm
end

;; ======================================================================

;; HELPER PROCEDURES

to-report find-flockmates ;; turtle procedure
  let refHeading heading
  let refTurtle self
  ;; Getting the turtles in a given radius
  let neighbours other turtles in-radius visionDistance
  ;; Then keeping only the ones in the sight field
  let neighboursInSight neighbours with [
    subtract-headings refHeading ([towards myself] of refTurtle) <= visionAngle
  ]
  report neighboursInSight
end

to-report find-nonFlockmates ;; turtle procedure
  let refHeading heading
  let refTurtle self
  let refColor color
  ;; Getting the turtles with different object type, ie different color (not default color) in a given radius
  let neighbours other turtles in-radius visionDistance with [refColor < 42 or refColor > 50 and color != refColor and (color < 42 or color > 50)]
  let neighboursInSight neighbours with [
  ;; Then keeping only the ones in the sight field
    subtract-headings refHeading ([towards myself] of refTurtle) <= visionAngle
  ]
  report neighboursInSight
end

to smoothTurn [newDirection] ;; turtle procedure
  if newDirection >= 0 [
    let turn (subtract-headings newDirection heading)
    ifelse abs turn > maxTurn [
      ifelse turn > 0
      [rt maxTurn]
      [lt maxTurn]
    ]
    [rt turn]
  ]
end

to-report find-objectives ;; turtle procedure
  let refHeading heading
  let refTurtle self
  let refColor color
  ;; Getting the patches with objects in a given radius
  let objectives other patches in-radius visionDistance with [pcolor != defaultPatchColor and refColor > 42 and refColor < 50]
  ;; Then keeping only the ones in the sight field
  let objectivesInSight objectives with [
    subtract-headings refHeading ([towards myself] of refTurtle) <= visionAngle
  ]
  report objectivesInSight
end

;; ======================================================================

;; CREATE AND REMOVE OBJECTS

to-report generateColor
  let rand random typeNumber + 1
  if rand <= 1 [report colorType1]
  if rand <= 2 [report colorType2]
  if rand <= 3 [report colorType3]
  if rand <= 4 [report colorType4]
end

to createObjects ;; observer procedure
  if objectProbability > 0 [
    if creationMode = "random" [
      ;; Adds objects in a random way
      ask patches [ addObject ]
    ]
    if creationMode = "packs" [
      ;; Chooses n random patches and creates packs of objects around them
      ask n-of 1 patches [ addPack ]
    ]
  ]
end

to addObject ;; patch procedure
  let rand random (100000 * (1 / objectProbability))
  if rand < 1 [
    set pcolor generateColor
  ]
end

to addPack ;; patch procedure
  let rand random (100 * (1 / objectProbability))
  if rand < 1 [
    let col generateColor
    set pcolor col
    ask neighbors [set pcolor col]
  ]
end

to pickUpObject ;; turtle procedure
  if pcolor != defaultPatchColor [
    ;; If pick up mode is on "clean", simply changes the patch color
    if pickUpMode = "clean" [
      set pcolor defaultPatchColor
      set removedObjects removedObjects + 1
    ]
    ;; If pick up mode is on "pick-up", changes the patch color AND the
    ;; turtle color, if the turtle is not already carrying an object
    if pickUpMode = "pick-up" and color > 42 and color < 50 [
      set color pcolor + 2
      set pcolor defaultPatchColor
      set removedObjects removedObjects + 1
    ]
  ]
end

;; ======================================================================

;; PERFORMANCE MEASURE

to performanceMeasure ;; observer procedure
  let perf count turtles with [find-flockmates = no-turtles]
  if performanceVersion = "mean" [
    ;; Version using MEAN value
    let t ticks + 1
    set performance (performance * ((t - 1) / t) + perf / t)
  ]
  ;; Version using RAW value
  if performanceVersion = "raw" [
    set performance perf
  ]
end

;; ======================================================================
@#$#@#$#@
GRAPHICS-WINDOW
253
10
758
516
-1
-1
7.0
1
10
1
1
1
0
1
1
1
-35
35
-35
35
1
1
1
ticks
30.0

BUTTON
19
108
131
150
setup
setup\nset minSpeed 0.5\nset maxSpeed 1\n;;set objectProbability 0\n;;set typeNumber 1
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
130
108
242
150
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
19
30
242
63
population
population
10
500.0
150.0
10
1
agents
HORIZONTAL

SLIDER
19
360
242
393
repulsionFactor
repulsionFactor
0
10
1.5
0.1
1
NIL
HORIZONTAL

SLIDER
19
393
242
426
alignmentFactor
alignmentFactor
0
10
4.0
0.1
1
NIL
HORIZONTAL

SLIDER
19
426
242
459
cohesionFactor
cohesionFactor
0
10
2.0
0.1
1
NIL
HORIZONTAL

SLIDER
19
173
242
206
visionDistance
visionDistance
0.0
10.0
3.0
0.5
1
patches
HORIZONTAL

SLIDER
19
305
242
338
maxTurn
maxTurn
0
360
8.0
1
1
°
HORIZONTAL

SLIDER
19
272
242
305
maxSpeed
maxSpeed
0.5
3
1.0
0.1
1
patchs/tick
HORIZONTAL

SLIDER
770
43
993
76
objectProbability
objectProbability
0
20
0.0
1
1
NIL
HORIZONTAL

PLOT
770
370
1278
628
Object quantity by type
time
objectPatches
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"type1" 1.0 0 -2674135 true "" "plot count patches with [pcolor = colorType1]"
"type2" 1.0 0 -13840069 true "" "plot count patches with [pcolor = colorType2]"
"type3" 1.0 0 -13345367 true "" "plot count patches with [pcolor = colorType3]"
"type4" 1.0 0 -2064490 true "" "plot count patches with [pcolor = colorType4]"

SLIDER
19
206
242
239
visionAngle
visionAngle
0
180
90.0
10
1
°
HORIZONTAL

SLIDER
19
239
242
272
minSpeed
minSpeed
0.1
0.5
0.5
0.1
1
patchs/tick
HORIZONTAL

TEXTBOX
774
10
997
43
Probability of object creation and number of different types
12
0.0
1

TEXTBOX
78
155
198
173
Flocking parameters
12
0.0
1

TEXTBOX
86
342
193
360
Force coefficients
12
0.0
1

CHOOSER
993
64
1135
109
creationMode
creationMode
"random" "packs"
0

TEXTBOX
999
29
1112
62
Changes the way objects are created
12
0.0
1

TEXTBOX
47
10
218
33
Number and shape of agents
12
0.0
1

CHOOSER
19
63
242
108
agentShape
agentShape
"default" "airplane" "bug" "turtle"
0

SLIDER
19
459
242
492
pickUpFactor
pickUpFactor
0
10
0.0
0.1
1
NIL
HORIZONTAL

SLIDER
770
76
993
109
typeNumber
typeNumber
1
4
1.0
1
1
NIL
HORIZONTAL

CHOOSER
1135
64
1277
109
pickUpMode
pickUpMode
"clean" "pick-up"
0

TEXTBOX
1140
29
1276
81
Ojects are cleaned or picked up by the agents
12
0.0
1

SLIDER
19
492
242
525
sortFactor
sortFactor
0
10
0.1
0.1
1
NIL
HORIZONTAL

SWITCH
18
567
241
600
repulsionSortActivated
repulsionSortActivated
1
1
-1000

TEXTBOX
20
535
202
580
Activates the repulsion component of the sort force
12
0.0
1

INPUTBOX
624
550
758
610
tickNumber
2000.0
1
0
Number

SWITCH
624
517
758
550
limitSimulation
limitSimulation
1
1
-1000

TEXTBOX
630
611
761
645
Limits the simulation to a given number of ticks
11
0.0
1

OUTPUT
381
517
624
610
12

BUTTON
253
550
381
583
Performance
clear-output\noutput-write (word \"Performance : \" performance)
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
770
112
1278
372
Performance measure : alone agents
time
agents alone
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"performance" 1.0 0 -2674135 true "" "plot performance"

TEXTBOX
387
612
615
640
Display performance measure or number of removed objects
11
0.0
1

BUTTON
253
517
381
550
Removed objects
clear-output\noutput-write (word \"Removed objects : \" removedObjects)
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
253
583
381
628
performanceVersion
performanceVersion
"mean" "raw"
0

@#$#@#$#@
## WHAT IS IT?

This model is an attempt to mimic the flocking of birds.  (The resulting motion also resembles schools of fish.)  The flocks that appear in this model are not created or led in any way by special leader birds.  Rather, each bird is following exactly the same set of rules, from which flocks emerge.

## HOW IT WORKS

The birds follow three rules: "alignment", "separation", and "cohesion".

"Alignment" means that a bird tends to turn so that it is moving in the same direction that nearby birds are moving.

"Separation" means that a bird will turn to avoid another bird which gets too close.

"Cohesion" means that a bird will move towards other nearby birds (unless another bird is too close).

When two birds are too close, the "separation" rule overrides the other two, which are deactivated until the minimum separation is achieved.

The three rules affect only the bird's heading.  Each bird always moves forward at the same constant speed.

## HOW TO USE IT

First, determine the number of birds you want in the simulation and set the POPULATION slider to that value.  Press SETUP to create the birds, and press GO to have them start flying around.

The default settings for the sliders will produce reasonably good flocking behavior.  However, you can play with them to get variations:

Three TURN-ANGLE sliders control the maximum angle a bird can turn as a result of each rule.

VISION is the distance that each bird can see 360 degrees around it.

## THINGS TO NOTICE

Central to the model is the observation that flocks form without a leader.

There are no random numbers used in this model, except to position the birds initially.  The fluid, lifelike behavior of the birds is produced entirely by deterministic rules.

Also, notice that each flock is dynamic.  A flock, once together, is not guaranteed to keep all of its members.  Why do you think this is?

After running the model for a while, all of the birds have approximately the same heading.  Why?

Sometimes a bird breaks away from its flock.  How does this happen?  You may need to slow down the model or run it step by step in order to observe this phenomenon.

## THINGS TO TRY

Play with the sliders to see if you can get tighter flocks, looser flocks, fewer flocks, more flocks, more or less splitting and joining of flocks, more or less rearranging of birds within flocks, etc.

You can turn off a rule entirely by setting that rule's angle slider to zero.  Is one rule by itself enough to produce at least some flocking?  What about two rules?  What's missing from the resulting behavior when you leave out each rule?

Will running the model for a long time produce a static flock?  Or will the birds never settle down to an unchanging formation?  Remember, there are no random numbers used in this model.

## EXTENDING THE MODEL

Currently the birds can "see" all around them.  What happens if birds can only see in front of them?  The `in-cone` primitive can be used for this.

Is there some way to get V-shaped flocks, like migrating geese?

What happens if you put walls around the edges of the world that the birds can't fly into?

Can you get the birds to fly around obstacles in the middle of the world?

What would happen if you gave the birds different velocities?  For example, you could make birds that are not near other birds fly faster to catch up to the flock.  Or, you could simulate the diminished air resistance that birds experience when flying together by making them fly faster when in a group.

Are there other interesting ways you can make the birds different from each other?  There could be random variation in the population, or you could have distinct "species" of bird.

## NETLOGO FEATURES

Notice the need for the `subtract-headings` primitive and special procedure for averaging groups of headings.  Just subtracting the numbers, or averaging the numbers, doesn't give you the results you'd expect, because of the discontinuity where headings wrap back to 0 once they reach 360.

## RELATED MODELS

* Moths
* Flocking Vee Formation
* Flocking - Alternative Visualizations

## CREDITS AND REFERENCES

This model is inspired by the Boids simulation invented by Craig Reynolds.  The algorithm we use here is roughly similar to the original Boids algorithm, but it is not the same.  The exact details of the algorithm tend not to matter very much -- as long as you have alignment, separation, and cohesion, you will usually get flocking behavior resembling that produced by Reynolds' original model.  Information on Boids is available at http://www.red3d.com/cwr/boids/.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1998).  NetLogo Flocking model.  http://ccl.northwestern.edu/netlogo/models/Flocking.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1998 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2002.

<!-- 1998 2002 -->
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
NetLogo 6.0
@#$#@#$#@
set population 200
setup
repeat 200 [ go ]
@#$#@#$#@
@#$#@#$#@
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
