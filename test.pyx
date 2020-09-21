# -*- coding: utf-8 -*-
# cython: language_level=3, cdivision=True, boundscheck=False, wraparound=False

"""Test objective function for algorithms.

author: Yuan Chang
copyright: Copyright (C) 2016-2020
license: AGPL
email: pyslvs@gmail.com
"""

cimport cython
from numpy import array, float64 as np_float
from .utility cimport ObjFunc


@cython.final
cdef class TestObj(ObjFunc):
    """Test objective function.

    f(x) = x1^2 + 8*x2
    """

    def __cinit__(self):
        self.ub = array([100, 100], dtype=np_float)
        self.lb = array([0, 0], dtype=np_float)

    cdef double target(self, double[:] v) nogil:
        return v[0] * v[0] + 8 * v[1]

    cdef double fitness(self, double[:] v) nogil:
        return self.target(v)

    cpdef object result(self, double[:] v):
        return tuple(v), self.target(v)