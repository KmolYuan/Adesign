# -*- coding: utf-8 -*-
# cython: language_level=3, cdivision=True, boundscheck=False, wraparound=False
# cython: initializedcheck=False, nonecheck=False

"""Test objective function for algorithms.

author: Yuan Chang
copyright: Copyright (C) 2016-2020
license: AGPL
email: pyslvs@gmail.com
"""

cimport cython
from cython.parallel cimport prange
from libc.math cimport exp
from numpy import array, zeros, float64 as np_float, random
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


cdef double[:] _test(double[:, :] x,  double[:] beta, double theta,
                        bint parallel):
    cdef double[:] y = zeros(x.shape[0])
    cdef double r = 0
    cdef unsigned i, j, d
    if parallel:
        for i in prange(x.shape[0], nogil=True):
            for j in range(x.shape[0]):
                r = 0
                for d in range(x.shape[1]):
                    r += (x[j, d] - x[i, d]) ** 2
                r = r ** 0.5
                y[i] += beta[j] * exp(-(r * theta) ** 2)
    else:
        for i in range(x.shape[0]):
            for j in range(x.shape[0]):
                r = 0
                for d in range(x.shape[1]):
                    r += (x[j, d] - x[i, d]) ** 2
                r = r ** 0.5
                y[i] += beta[j] * exp(-(r * theta) ** 2)
    return y


def with_mp():
    _test(array([random.rand(1000) for d in range(5)]).T,
          random.rand(1000), 10, True)


def without_mp():
    _test(array([random.rand(1000) for d in range(5)]).T,
          random.rand(1000), 10, False)
