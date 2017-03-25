# Effects of Swarming on Learning Rate of a Population

## Introduction

The Upper Paleolithic (UP) transition shows evidence of rapid technological advancement. In this research we will attempt to reproduce Powell et al. [2009]'s findings on the advancement of knowledge during the UP transition using a modified version of Henrich [2004]'s transmission model. The aim is to explore the benefits of a more social population, simulated through an increased tendency for turtles to swarm.

If Powell et al. [2009]'s findings are correct, we should observe an increase in learning speed as a turtles opt to socialize during a higher proportion of their time. We also hope to observe an exponential increase in learning as individuals start to require less resources and can therefore live in higher densities.

## Signaling

We use Henrich [2004]'s work as a base for our signaling model. Turtles can misinterpret each other's foraging behavior, causing learning to have a chance of being detrimental. A 40% chance of learning being beneficial to the learner is applied, making communication detrimental on average. As turtles learn from turtles with the highest level of knowledge in the area, given enough signaling, the mean knowledge level is expected to rise.

The turtles learn by observation, simulating copying foraging turtles in the vicinity. To prevent instant propagation of knowledge across the entire population, a turtle can only become as good as half the combined knowledge of itself and the teacher.

## Methodology

Turtles are spawned in ten small colonies of fifty individuals with evenly distributed age and gamma distributed energy. The initial count and density is too high for the area so some turtles initially die due to overpopulation before a sustainable density is reached.

Swarming behavior is simulated through the turtles movement. Turtles will forage for food until they gain a certain level of energy, at which point they will meander to the highest concentration of turtles within visible distance. This distance is higher than the signaling distance, so turtles benefit from wandering into a more populous area. This action carries a risk of turtles starving as it enters an overpopulated area.

This is a simplified version of the three-zones model used by AOKI [1982] and Huth and Wissel [1992] to simulate schools of fish. We opt to ignore the average velocity of the to prevent colonies moving, colliding and coalescing.

Throughout testing we vary the probability of a turtle meandering towards a more populated area, thereby simulating the willingness of an individual to socialize. In fig \ref{fig:swarming} the effect of probability can be observed to be working as intended.

We use Edwards et al. [2007]'s gamma distributed movement distance to simulate movement per tick for each individual.

<img src="https://github.com/domhauton/CM30229-Netlogo-Simulation/blob/master/writeup/imgs/swarming-high.png" alt="High Density Swarming" width="200"/> <img src="https://github.com/domhauton/CM30229-Swarming-Simulation/blob/master/writeup/imgs/swarming-low.png" alt="Low Density Swarming" width="200"/>

Figure 1: Swarming Levels - 1.0 & 0.8 resp.

The simulation is performed in Netlogo 6.0. The code is forked from a similar project by Čače and Bryson [2007]. Fifty runs of simulation are performed for each of the tested swarming probabilities.

## Results

The results of the simulation show an expected and statistically significant increase (using a p-value of 0.05) in knowledge progression within the population. Fig 2 shows an maximal knowledge progression occurring when turtles spent all of their free time in the swarm, only venturing out when hungry. There was no knowledge progression with a swarming rate of 0.7. Swarming values below 0.7 show no significant effects on learning, so we use 0.7 as our base reading.

<img src="https://github.com/domhauton/CM30229-Swarming-Simulation/blob/master/writeup/imgs/swarming-effect.png" alt="Knowledge vs. Time Graph" width="400"/>

Figure 2: Knowledge vs Time - Results

An interesting observation is that fertile ground is required for swarming without the repulsion factor described by Agueh et al. [2011].

When the food replacement rate is dropped past a critical point the swarming behavior leads to sudden death within the swarm as the members cannot get out of the highly populated area fast enough to eat. When the swarm dies the knowledge built up within it is lost.

## Conclusion

We successfully managed to reproduce the increased rate of learning as population density is increased, demonstrated by Powell et al. [2009]. We have further shown that within a colony it is beneficial for members to spend as much time as possible in high density areas, as knowledge progression is accelerated.

The demise of a colony when the food replacement rate dropped may well be an explanation of sparks of intelligence observed during the UP transition, as described by Powell et al. [2009]. During prosperous times, more social colonies excelled, but as natural resources wained, those more social met their demise, while less social, slower learners prevailed.

Although this work shows the benefits of a denser population it may be beneficial use a more complex swarming mechanism to see if similar results can be observed.

The model is also rather simple, with only one constant type of resource. It would be interesting to see colonies at 0.9 and 1.0 swarming probability cope with fluctuating food replacement rates, to see if the knowledge spikes in the UP transition can be reproduced. 

## Bibliography

Martial Agueh, Reinhard Illner, and AshlinRichardson. Analysis and simulations ofa refined flocking and swarming model of cucker-smale type. Kinetic and Related Science, 324(5932): 1298–1301, 2009. Models, 4(1):1–16, 2011.

Ichiro AOKI. A simulation study on the schooling mechanism in fish. NIPPON SUISAN GAKKAISHI, 48(8):1081–1088, 1982. doi: 10.2331/suisan.48.1081.

Ivana Čače and Joanna J Bryson. Agent based modelling of communication costs: Why information can be free. In Emergence of Communication and Language, pages 305–321. Springer, 2007.

Andrew M Edwards, Richard A Phillips, Nicholas W Watkins, Mervyn P Freeman, Eugene J Murphy, Vsevolod Afanasyev, Sergey V Buldyrev, Marcos GE da Luz, Ernesto P Raposo, H Eugene Stanley, et al. Revisiting lévy flight search pat-terns of wandering albatrosses, bumble-bees and deer. Nature, 449(7165):1044–1048, 2007.

Joseph Henrich. Demography and cultural evolution: how adaptive cultural processes can produce maladaptive losses: the tasmanian case. American Antiquity,pages 197–214, 2004.

Andreas Huth and Christian Wissel. Thesimulation of the movement of fishschools. Journal of theoretical biology, 156(3):365–385, 1992.

Adam Powell, Stephen Shennan, and Mark G Thomas. Late pleistocene demography and the appearance of modern human behavior.
