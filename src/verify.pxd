# -*- coding: utf-8 -*-
# cython: language_level=3

"""The callable class of the validation in algorithm.

author: Yuan Chang
copyright: Copyright (C) 2016-2018
license: AGPL
email: pyslvs@gmail.com
"""

import numpy as np
cimport numpy as np


cdef enum limit:
    maxGen
    minFit
    maxTime


cdef class Chromosome:
    cdef public int n
    cdef public double f
    cdef public np.ndarray v

    cdef double distance(self, Chromosome obj)
    cpdef void assign(self, Chromosome obj)


cdef class Verification:
    cdef np.ndarray get_upper(self)
    cdef np.ndarray get_lower(self)
    cdef int get_nParm(self)
    cpdef object result(self, np.ndarray v)
