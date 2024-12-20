function test_suite = test_lgmres %#ok<*STOUT>
    %
    %   Modified from:
    %   https://github.com/Remi-Gau/template_matlab_analysis
    %
    %   Copyright:
    %   ----------
    %
    %   This file is part of the KrySBAS MATLAB Toolbox.
    %
    %   Copyright 2023 CC&MA - NIDTec - FP - UNA
    %
    %   KrySBAS is free software: you can redistribute it and/or modify it under
    %   the terms of the GNU General Public License as published by the Free
    %   Software Foundation, either version 3 of the License, or (at your
    %   option) any later version.
    %
    %   KrySBAS is distributed in the hope that it will be useful, but WITHOUT
    %   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    %   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
    %   for more details.
    %
    %   You should have received a copy of the GNU General Public License along
    %   with this file.  If not, see <http://www.gnu.org/licenses/>.
    %

    try % assignment of 'localfunctions' is necessary in Matlab >= 2016
        test_functions = localfunctions(); %#ok<*NASGU>
    catch % no problem; early Matlab versions can use initTestSuite fine
    end

    initTestSuite;

end

% ----> Test for sanity checks

function test_number_of_input_arguments()
    % Test if error is raised when passing incorrect number of inputs.
    % Error should be raised since 1 parameter is given
    try
        lgmres(ones(2, 2));
    catch ME
        msg = "Too few input parameters. Expected at least A and b.";
        assert(matches(ME.message, msg));
    end

    % Error should be raised since 8 parameters are given
    try
        lgmres([], [], [], [], [], [], [], []);
    catch ME
        msg = "Too many input parameters.";
        assert(matches(ME.message, msg));
    end
end

function test_empty_matrix_A()
    % Test if error is raised when an empty matrix A is given.
    try
        lgmres([], 1);
    catch ME
        msg = 'Matrix A cannot be empty.';
        assert(matches(ME.message, msg));
    end
end

function test_non_square_matrix_A()
    % Test if error is raised when matrix A is not squared
    try
        lgmres([1; 1], [1; 1]);
    catch ME
        msg = "Matrix A must be square.";
        assert(matches(ME.message, msg));
    end
end

function test_empty_vector_b()
    % Test if error is raised when vector b is empty
    try
        lgmres(1, []);
    catch ME
        msg = "Vector b cannot be empty.";
    end
end

function test_vector_b_not_column_vector()
    % Test if error is raised when vector b is not a column vector
    try
        lgmres(ones(2), [1, 1]);
    catch ME
        msg = "Vector b must be a column vector.";
    end
end

function test_size_compatibility_between_A_and_b()
    % Test if error is raised when the dimensionality of A and b differs
    try
        lgmres(ones(3), [1; 1]);
    catch ME
        msg = "Dimension mismatch between matrix A and vector b.";
    end
end

function test_default_value_of_m()
    % Test if default value of m is set to min(n, 10)
    % and full GMREs is run when input parameters are A and B only

    A = eye(3);
    b = ones(3, 1);

    [x, flag, ~, ~] = lgmres(A, b);

    assertElementsAlmostEqual(x, ones(3, 1));
    assert(flag == 1);
end

function test_m_greater_than_size_of_A()
    % Test if error is raised when m > size(A, 1)

    A = eye(3);
    b = ones(3, 1);

    try
        lgmres(A, b, 4);
    catch ME
        msg = "m must satisfy: 1 <= m <= n.";
        assert(matches(ME.message, msg));
    end
end

function test_full_gmres_when_m_equals_size_of_A()
    % Test if built-in unrestarted GMRES is set
    % when m == size(A, 1)

    A = eye(3);
    b = ones(3, 1);

    x1 = gmres(A, b);
    [x2, flag, relresvec, time] = lgmres(A, b, 3, 0);

    assertElementsAlmostEqual(x1, x2);
    assert(flag == 1);
    assertElementsAlmostEqual(relresvec, [1; 0]);
    assert(time > 0 && time < 5);
end

function test_restarted_gmres_when_m_is_less_than_size_of_A()
    % Test if built-in restarted GMREs is set
    % when m < size(A, 1)
    A = eye(3);
    b = ones(3, 1);

    x1 = gmres(A, b, 2);
    [x2, flag, relresvec, time] = lgmres(A, b, 2, 0);

    assertElementsAlmostEqual(x1, x2);
    assert(flag == 1);
    assertElementsAlmostEqual(relresvec, [1; 0]);
    assert(time > 0 && time < 5);
end

function test_vector_xInitial_not_column_vector()
    % Test if error is raised when xInitial is not a column vector

    A = eye(3);
    b = ones(3, 1);
    x0 = ones(1, 3);

    try
        lgmres(A, b, [], [], [], [], x0);
    catch ME
        msg = "Initial guess xInitial is not a column vector.";
        assert(matches(ME.message, msg));
    end
end

function test_size_compatibility_between_A_and_xInitial()
    % Test size compatibility between A and xInitial

    A = eye(3);
    b = ones(3, 1);
    x0 = ones(2, 1);

    try
        lgmres(A, b, [], [], [], [], x0);
    catch ME
        msg = "Dimension mismatch between matrix A and initial guess xInitial.";
        assert(matches(ME.message, msg));
    end
end

% Check the name of this function
function test_outputs_unrestarted_identity_matrix() % Linear system # 1
    % Test whether the correct outputs are returned using an identity
    % matrix when the unrestarted algorithm is called

    % Setup a trivial linear system
    n = 100;
    A = eye(n);
    b = ones(n, 1);
    xInitial = zeros(n, 1);

    % Call LGMRES
    [x, flag, relresvec, time] = lgmres(A, b, 27, 3, 1e-6, 100, xInitial);

    % Compare with expected outputs
    assertElementsAlmostEqual(x, ones(n, 1));
    assert(flag == 1);
    assertElementsAlmostEqual(relresvec, [1; 0]);
    assert(time > 0 && time < 5);
end

% Check the name of this function
function test_outputs_restarted_identity_matrix() % Linear system # 2
    % Test whether the correct outputs are returned using an identity
    % matrix when the restarted algorithm is called

    % Setup a trivial linear system
    n = 3;
    A = eye(n);
    b = [2; 3; 4];
    xInitial = zeros(n, 1);

    % Call LGMRES
    [x, flag, relresvec, time] = lgmres(A, b, 2, 1, 1e-6, 100, xInitial);

    % Compare with expected outputs
    assertElementsAlmostEqual(x, [2; 3; 4]);
    assert(flag == 1);
    assertElementsAlmostEqual(relresvec, [1; 0]);
    assert(time > 0 && time < 5);

end

function test_embree_three_by_three_toy_example()
    % Test Embree's 3x3 linear system from https://www.jstor.org/stable/25054403

    % Load A and b
    load('data/embree3.mat', 'Problem');
    A = Problem.A;
    b = Problem.b;

    % Setup LGMRES
    m = 2;
    k = 1;
    tol = 1e-6;
    maxit = 100;

    % Call LGMRES
    [x, flag, ~, ~] = ...
        lgmres(A, b, m, k, tol, maxit);

    % Compare with expected outputs
    assertElementsAlmostEqual(x, [8; -7; 1]);
    assertEqual(flag, 1);

end

function test_sherman_one()
    % Test lgmres with sherman1 matrix

    % Load A and b
    load('data/sherman1.mat', 'Problem');
    A = Problem.A;
    b = Problem.b;

    % Setup LGMRES
    m = 27;
    k = 3;
    tol = 1e-12;
    maxit = 1000;

    % Call LGMRES
    [~, flag, relresvec, ~] = ...
            lgmres(A, b, m, k, tol, maxit);

    % We check if it has converged and the total sum of outer iterations
    assertEqual(flag, 1);
    assertEqual(size(relresvec, 1), 39);
end

function test_sherman_four()
    % Test lgmres with sherman4 matrix

    % Load A and b
    load('data/sherman4.mat', 'Problem');
    A = Problem.A;
    b = Problem.b;

    % Setup LGMRES
    m = 27;
    k = 3;
    tol = 1e-12;
    maxit = 1000;

    % Call LGMRES
    [~, flag, relresvec, ~] = ...
            lgmres(A, b, m, k, tol, maxit);

    % We check if it has converged and the total sum of outer iterations
    assertEqual(flag, 1);
    assertEqual(size(relresvec, 1), 18);
end
