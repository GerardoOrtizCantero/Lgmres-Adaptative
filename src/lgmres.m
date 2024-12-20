function [x, flag, relresvec, time] = ...
    lgmres(A, b, m, k, tol, maxit, xInitial, varargin)
    % LGMRES algorithm
    %
    %   LGMRES ("Loose GMRES") is a modified implementation of the restarted
    %   Generalized Minimal Residual Error or GMRES(m) [1], performed by
    %   appending 'k' error approximation vectors to the restarting Krylov
    %   subspace, as a way to preserve information from previous
    %   discarted search subspaces from previous iterations of the method.
    %
    %   Augments the standard GMRES approximation space with approximations
    %   to the error from previous restart cycles as in [1].
    %
    %   Signature:
    %   ----------
    %
    %   [x, flag, relresvec, time] = ...
    %       lgmres(A, b, m, k, tol, maxit, xInitial)
    %
    %
    %   Input Parameters:
    %   -----------------
    %
    %   A:          n-by-n matrix
    %               Left-hand side of the linear system Ax = b.
    %
    %   b:          n-by-1 vector
    %               Right-hand side of the linear system Ax = b.
    %
    %   m:          int
    %               Restart parameter (similar to 'restart' in MATLAB).
    %
    %   k:          int
    %               Number of error approximation vectors to be appended
    %               to the Krylov search subspace. Default is 3, but values
    %               between 1 and 5 are mostly used.
    %
    %   tol:        float, optional
    %               Tolerance error threshold for the relative residual norm.
    %               Default is 1e-6.
    %
    %   maxit:      int, optional
    %               Maximum number of outer iterations.
    %
    %   xInitial:   n-by-1 vector, optional
    %               Vector of initial guess. Default is zeros(n, 1).
    %
    %   Output parameters:
    %   ------------------
    %
    %   x:          n-by-1 vector
    %               Approximate solution to the linear system.
    %
    %   flag:       boolean
    %               1 if the algorithm has converged, 0 otherwise.
    %
    %   relressvec: (1 up to maxit)-by-1 vector
    %               Vector of relative residual norms of every outer iteration
    %               (cycles). The last relative residual norm is simply given
    %               by relresvec(end).
    %
    %   mvec:       (1 up to maxit)-by-1 vector
    %               Vector of restart parameter values. In case the
    %               unrestarted algorithm is invoked, mvec = NaN.
    %
    %   time:       scalar
    %               Computational time in seconds.
    %
    %   References:
    %   -----------
    %
    %   [1] Baker, A. H., Jessup, E. R., & Manteuffel, T. (2005). A technique
    %   for accelerating the convergence of restarted GMRES. SIAM Journal on
    %   Matrix Analysis and Applications, 26(4), 962-984.
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

    % ----> Sanity check on the number of input parameters
    if nargin < 2
        error("Too few input parameters. Expected at least A and b.");
    elseif nargin > 8
        error("Too many input parameters.");
    end

    % ----> Sanity checks on matrix A
    % Check whether A is non-empty
    if isempty(A)
        error("Matrix A cannot be empty.");
    end

    % Check whether A is square
    [rowsA, colsA] = size(A);
    if rowsA ~= colsA
        error("Matrix A must be square.");
    end

    n = rowsA;
    clear rowsA colsA;

    % ----> Sanity checks on vector b
    % Check whether b is non-empty
    if isempty(b)
        error("Vector b cannot be empty.");
    end

    % Check whether b is a column vector
    [rowsb, colsb] = size(b);
    if colsb ~= 1
        error("Vector b must be a column vector.");
    end

    % Check whether b has the same number of rows as b
    if rowsb ~= n
        error("Dimension mismatch between matrix A and vector b.");
    end

    clear rowsb colsb;

    % Special sanity checks for LGMRES here

    % ----> Default value and sanityu checks for m
    if (nargin < 3) || isempty(m)
        m = min(n, 10);
    end

    % ----> If m > n, error message is printed
    if m > n
        error("m must satisfy: 1 <= m <= n.");
    end

    % ----> If m == n, built-in unrestarted gmres will be used
    if m == n
        warning("Full GMRES will be used.");
        tic();
        [gmres_x, gmres_flag, ~, ~, resvec] = gmres(A, b);
        time = toc();
        x = gmres_x;
        if gmres_flag == 0
            flag = 1;
        else
            flag = 0;
        end
        relresvec = resvec ./ resvec(1, 1);
        return
    end

    % ----> If m < n AND k == 0, built-in gmres(m) will be used
    if (m < n) && (k == 0)
        warning("GMRES(m) will be used.");
        tic();
        [gmres_x, gmres_flag, ~, ~, resvec] = gmres(A, b, m);
        time = toc();
        x = gmres_x;
        if gmres_flag == 0
            flag = 1;
        else
            flag = 0;
        end
        relresvec = resvec ./ resvec(1, 1);
        return
    end

    % ----> Default value and sanity checks for k
    if (nargin < 4) || isempty(k)
        k = 3;
    end

    % Default value and sanity checks for tol
    if (nargin < 5) || isempty(tol)
        tol = 1e-6;
    end

    if tol < eps
        warning("Tolerance is too small and it will be changed to eps.");
        tol = eps;
    elseif tol >= 1
        warning("Tolerance is too large and it will be changed to 1-eps.");
        tol = 1 - eps;
    end

    % ----> Default value for maxit
    if (nargin < 6) || isempty(maxit)
        maxit = min(n, 10);
    end

    % ----> Default value and sanity checks for initial guess xInitial
    if (nargin < 7) || isempty(xInitial)
        xInitial = zeros(n, 1);
    end

    % Check whether xInitial is a column vector
    [rowsxInitial, colsxInitial] = size(xInitial);
    if colsxInitial ~= 1
        error("Initial guess xInitial is not a column vector.");
    end

    % Check whether x0 has the right dimension
    if rowsxInitial ~= n
        msg = "Dimension mismatch between matrix A and initial guess xInitial.";
        error(msg);
    end

    clear rowsxInitial colsxInitial;

    % ---> LGMRES Algorithm starts here
    % First outer iteration is a simple restarted GMRES(m) execution
    % First approximation error vector is created in this stage

    % Algorithm setup
    restart = 1;
    r0 = b - A * xInitial;
    res(1, :) = norm(r0);
    relresvec(1, :) = (norm(r0) / res(1, 1));
    iter(1, :) = restart;

    % Matrix with the history of approximation error vectors
    zMat = zeros(n, k);

    % while number_of_cycles <=k, we run GMRES(m + k) only

    tic(); % start measuring CPU time

    % Call MATLAB built-in gmres.
    % Ref. [1], pag. 968, recommends GMRES(m + k)
    % if no enough approximation error vectors are stored yet.
    [x, gmres_flag, ~, ~, resvec] = ...
        gmres(A, b, m + k, tol, 1, [], [], xInitial);

    % Update residual norm, iterations, and relative residual vector
    res(restart + 1, :) = resvec(end);
    iter(restart + 1, :) = restart + 1;
    relresvec(size(relresvec, 1) + 1, :) = resvec(end) / res(1, 1);
    % First approximation error vector
    zMat(:, restart) = x - xInitial;

    % gmres uses a flag system. We only care whether the solution has
    % converged or not
    if gmres_flag ~= 0 % if gmres did not converge
        flag = 0;
        xInitial = x;
        restart = restart + 1;
    else
        flag = 1;
        time = toc();
        return
    end

    % ---> LGMRES Algorithm for restart > 1 or
    % LGMRES(m, k)

    while flag == 0 && restart <= maxit

        % Compute normalized residual vector
        r = b - A * xInitial;
        beta = norm(r);
        v1 = r / beta;

        % Modified Gram-Schmidt Arnoldi iteration
        % Notice that for augmented Krylov subspaces, we need zHistory
        % where zHistory, a n-by-k matrix, is the history of approximation
        % error vectors from the last outer iterations
        % For LGMRES we must take in consideration that
        % s = m + k is related to the size of
        % output parameteres H, V
        [H, V, s] = ...
            augmented_gram_schmidt_arnoldi ...
            (A, v1, m + k - min(restart - 1, k), ...
             zMat(:, 1:min(restart - 1, k)));

        % Plane rotations
        [HUpTri, g] = plane_rotations(H, beta);

        % Solve the least-squares problem
        Rs = HUpTri(1:s, 1:s);
        gs = g(1:s);
        minimizer = Rs \ gs;

        % From [1], fig. 1, lines 10 and 12, the n-by-s matrix W
        % is created with the first m Arnoldi vectors and the
        % k approximation error vectos, from newest to oldest,
        % zCurrentCycle is the approximation error vector from
        % the current outer iteration
        W = zeros(n, s);
        W(:, 1:m + k - min(restart - 1, k)) = ...
            V(:, 1:m + k - min(restart - 1, k));
        W(:, m + k - min(restart - 1, k) + 1:s) = ...
            fliplr(zMat(:, 1:min(restart - 1, k)));
        zCurrentCycle = W * minimizer;
        xm = xInitial + zCurrentCycle;

        % Update residual norm, iterations, and relative residual vector
        res(restart + 1, :) = abs(g(s + 1, 1));
        iter(restart + 1, :) = restart + 1;
        relresvec(size(relresvec, 1) + 1, :) = ...
            res(restart + 1, :) / res(1, 1);

        % Check convergence
        if relresvec(restart + 1, 1) < tol
            % We reached convergence.
            flag = 1;
            x = xm;
            time = toc();
            return
        elseif restart <= maxit

            % We have not reached convergence. Update and restart.
            xInitial = xm;

            % Storage of approximation error vector
            if restart <= k
                zMat(:, restart) = zCurrentCycle;
            else
                zMat(:, 1:k - 1) = zMat(:, 2:k);
                zMat(:, k) = zCurrentCycle;
            end

            restart = restart + 1;
        end

    end

    time = toc();

end
