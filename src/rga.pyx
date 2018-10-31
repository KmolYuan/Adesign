# -*- coding: utf-8 -*-
# cython: language_level=3

"""Real-coded Genetic Algorithm.

__author__ = "Yuan Chang"
__copyright__ = "Copyright (C) 2016-2018"
__license__ = "AGPL"
__email__ = "pyslvs@gmail.com"
"""

cimport cython
from libc.math cimport pow
import numpy as np
cimport numpy as np
from verify cimport (
    limit,
    maxGen,
    minFit,
    maxTime,
    Chromosome,
    Verification,
)
from libc.stdlib cimport rand, RAND_MAX, srand
from time import time
srand(int(time()))


cdef double rand_v():
    return rand() / (RAND_MAX * 1.01)


@cython.final
cdef class Genetic:

    """Algorithm class."""

    cdef limit option
    cdef int nParm, nPop, maxGen, maxTime, gen, rpt
    cdef double pCross, pMute, pWin, bDelta, iseed, mask, seed, minFit, time_start
    cdef Verification func
    cdef object progress_fun, interrupt_fun
    cdef np.ndarray chrom, newChrom, babyChrom
    cdef Chromosome chromElite, chromBest
    cdef np.ndarray maxLimit, minLimit
    cdef list fitnessTime

    def __cinit__(
        self,
        func: Verification,
        settings: dict,
        progress_fun: object = None,
        interrupt_fun: object = None
    ):
        """
        settings = {
            'nPop',
            'pCross',
            'pMute',
            'pWin',
            'bDelta',
            'maxGen' or 'minFit' or 'maxTime',
            'report'
        }
        """
        self.func = func
        self.nParm = self.func.get_nParm()
        self.nPop = settings['nPop']
        self.pCross = settings['pCross']
        self.pMute = settings['pMute']
        self.pWin = settings['pWin']
        self.bDelta = settings['bDelta']
        self.maxGen = 0
        self.minFit = 0
        self.maxTime = 0
        if 'maxGen' in settings:
            self.option = maxGen
            self.maxGen = settings['maxGen']
        elif 'minFit' in settings:
            self.option = minFit
            self.minFit = settings['minFit']
        elif 'maxTime' in settings:
            self.option = maxTime
            self.maxTime = settings['maxTime']
        else:
            raise Exception("Please give 'maxGen', 'minFit' or 'maxTime' limit.")
        self.rpt = settings['report']
        self.progress_fun = progress_fun
        self.interrupt_fun = interrupt_fun

        # low bound
        self.minLimit = self.func.get_lower()
        # up bound
        self.maxLimit = self.func.get_upper()

        self.chrom = np.ndarray(self.nPop, dtype=np.object)
        self.newChrom = np.ndarray(self.nPop, dtype=np.object)
        self.babyChrom = np.ndarray(3, dtype=np.object)
        cdef int i
        for i in range(self.nPop):
            self.chrom[i] = Chromosome(self.nParm)
        for i in range(self.nPop):
            self.newChrom[i] = Chromosome(self.nParm)
        for i in range(3):
            self.babyChrom[i] = Chromosome(self.nParm)

        self.chromElite = Chromosome(self.nParm)
        self.chromBest = Chromosome(self.nParm)

        # generations
        self.gen = 0

        # setup benchmark
        self.time_start = time()
        self.fitnessTime = []

    cdef inline double rand_val(self, double low, double high):
        return rand_v() * (high - low) + low

    cdef inline double check(self, int i, double v):
        """If a variable is out of bound, replace it with a random value."""
        if v > self.maxLimit[i] or v < self.minLimit[i]:
            return self.rand_val(self.minLimit[i], self.maxLimit[i])
        return v

    cdef inline void initial_pop(self):
        cdef int i, j
        for j in range(self.nPop):
            for i in range(self.nParm):
                self.chrom[j].v[i] = self.rand_val(self.minLimit[i], self.maxLimit[i])

    cdef inline void cross_over(self):
        cdef int i, s, j
        for i in range(0, self.nPop - 1, 2):
            if not rand_v() < self.pCross:
                continue
            for s in range(self.nParm):
                # first baby, half father half mother
                self.babyChrom[0].v[s] = 0.5 * self.chrom[i].v[s] + 0.5*self.chrom[i+1].v[s]
                # second baby, three quaters of fater and quater of mother
                self.babyChrom[1].v[s] = self.check(s, 1.5 * self.chrom[i].v[s] - 0.5 * self.chrom[i+1].v[s])
                # third baby, quater of fater and three quaters of mother
                self.babyChrom[2].v[s] = self.check(s, -0.5 * self.chrom[i].v[s] + 1.5 * self.chrom[i+1].v[s])
            # evaluate new baby
            for j in range(3):
                self.babyChrom[j].f = self.func(self.babyChrom[j].v)
            # maybe use bubble sort? smaller -> larger
            if self.babyChrom[1].f < self.babyChrom[0].f:
                self.babyChrom[0], self.babyChrom[1] = self.babyChrom[1], self.babyChrom[0]
            if self.babyChrom[2].f < self.babyChrom[0].f:
                self.babyChrom[2], self.babyChrom[0] = self.babyChrom[0], self.babyChrom[2]
            if self.babyChrom[2].f < self.babyChrom[1].f:
                self.babyChrom[2], self.babyChrom[1] = self.babyChrom[1], self.babyChrom[2]
            # replace first two baby to parent, another one will be
            self.chrom[i].assign(self.babyChrom[0])
            self.chrom[i + 1].assign(self.babyChrom[1])

    cdef inline double delta(self, double y):
        cdef double r
        if self.maxGen > 0:
            r = self.gen / self.maxGen
        else:
            r = 1
        return y * rand_v() * pow(1.0 - r, self.bDelta)

    cdef inline void fitness(self):
        cdef int j
        for j in range(self.nPop):
            self.chrom[j].f = self.func(self.chrom[j].v)
        self.chromBest.assign(self.chrom[0])
        for j in range(1, self.nPop):
            if self.chrom[j].f < self.chromBest.f:
                self.chromBest.assign(self.chrom[j])
        if self.chromBest.f < self.chromElite.f:
            self.chromElite.assign(self.chromBest)

    cdef inline void mutate(self):
        cdef int i, s
        for i in range(self.nPop):
            if not rand_v() < self.pMute:
                continue
            s = int(rand_v() * self.nParm)
            if int(rand_v() * 2) == 0:
                self.chrom[i].v[s] += self.delta(self.maxLimit[s] - self.chrom[i].v[s])
            else:
                self.chrom[i].v[s] -= self.delta(self.chrom[i].v[s] - self.minLimit[s])

    cdef inline void report(self):
        self.fitnessTime.append((self.gen, self.chromElite.f, time() - self.time_start))

    cdef inline void select(self):
        """
        roulette wheel selection
        """
        cdef int i, j, k
        for i in range(self.nPop):
            j = int(rand_v() * self.nPop)
            k = int(rand_v() * self.nPop)
            self.newChrom[i].assign(self.chrom[j])
            if self.chrom[k].f < self.chrom[j].f and rand_v() < self.pWin:
                self.newChrom[i].assign(self.chrom[k])
        # in this stage, newChrom is select finish
        # now replace origin chromosome
        for i in range(self.nPop):
            self.chrom[i].assign(self.newChrom[i])
        # select random one chromosome to be best chromosome, make best chromosome still exist
        j = int(rand_v() * self.nPop)
        self.chrom[j].assign(self.chromElite)

    cdef inline void generation_process(self):
        self.select()
        self.cross_over()
        self.mutate()
        self.fitness()
        if self.rpt:
            if self.gen % self.rpt == 0:
                self.report()
        else:
            if self.gen % 10 == 0:
                self.report()

    cpdef tuple run(self):
        """Init and run GA for maxGen times."""
        self.initial_pop()
        self.chrom[0].f = self.func(self.chrom[0].v)
        self.chromElite.assign(self.chrom[0])
        self.fitness()
        self.report()
        while True:
            self.gen += 1
            if self.option == maxGen:
                if 0 < self.maxGen < self.gen:
                    break
            elif self.option == minFit:
                if self.chromElite.f <= self.minFit:
                    break
            elif self.option == maxTime:
                if 0 < self.maxTime <= time() - self.time_start:
                    break
            self.generation_process()
            # progress
            if self.progress_fun:
                self.progress_fun(self.gen, f"{self.chromElite.f:.04f}")
            # interrupt
            if self.interrupt_fun and self.interrupt_fun():
                break
        self.report()
        return self.func.result(self.chromElite.v), self.fitnessTime
