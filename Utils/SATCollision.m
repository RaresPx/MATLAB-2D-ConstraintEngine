function [isColliding, normal, penetration, MTV] = SATCollision(bodyA, bodyB)
% SATCollision  SAT polygon collision with broad phase & MTV output.
%   [isColliding, normal, penetration, MTV] = SATCollision(bodyA, bodyB)
%
%   normal:      unit normal A -> B
%   penetration: scalar (minimum overlap)
%   MTV:         minimum translation vector to resolve penetration

    normal = [0;0];
    penetration = 0;
    MTV = [0;0];
    isColliding = true;

    %% ------------------------------------------------------------
    % Broad Phase: Bounding Circle
    %% ------------------------------------------------------------
    rA = getBoundingRadius(bodyA);
    rB = getBoundingRadius(bodyB);

    delta = bodyB.Pos - bodyA.Pos;
    distSq = dot(delta, delta);
    radSum = rA + rB;

    if distSq > radSum^2
        % Too far apart to collide
        isColliding = false;
        return;
    end

    %% ------------------------------------------------------------
    % Narrow Phase: SAT
    %% ------------------------------------------------------------
    A = bodyA.getVertices();
    B = bodyB.getVertices();

    axes = [computeAxes(A), computeAxes(B)];

    centerA = bodyA.Pos;
    centerB = bodyB.Pos;
    directionAB = centerB - centerA;

    minOverlap = inf;
    bestAxis = [0;0];

    for i = 1:size(axes,2)
        axis = axes(:,i);

        % Make the axis point A → B
        if dot(axis, directionAB) < 0
            axis = -axis;
        end

        % Project polygons
        [minA, maxA] = projectOntoAxis(A, axis);
        [minB, maxB] = projectOntoAxis(B, axis);

        overlap = min(maxA - minB, maxB - minA);

        % Separating axis → no collision
        if overlap <= 0
            isColliding = false;
            normal = [0;0];
            penetration = 0;
            MTV = [0;0];
            return;
        end

        % Keep the smallest overlap
        if overlap < minOverlap
            minOverlap = overlap;
            bestAxis = axis;
        end
    end

    %% ------------------------------------------------------------
    % Collision result
    %% ------------------------------------------------------------
    penetration = minOverlap;
    normal = bestAxis / norm(bestAxis);
    MTV = normal * penetration;
end


%% ---------- Helper: bounding radius ----------
function r = getBoundingRadius(body)
    if strcmp(body.Shape, "circle")
        r = body.Radius;
    else
        % Rectangle: diagonal/2
        r = sqrt((body.Width/2)^2 + (body.Height/2)^2);
    end
end


%% ---------- Helper: Compute edge normals ----------
function axes = computeAxes(V)
    n = size(V,2);
    axes = zeros(2,n);
    for i = 1:n
        j = mod(i, n) + 1;
        edge = V(:,j) - V(:,i);
        normal = [-edge(2); edge(1)];
        len = norm(normal);
        if len > 1e-12
            normal = normal / len;
        end
        axes(:,i) = normal;
    end
end


%% ---------- Helper: Project polygon onto axis ----------
function [minProj, maxProj] = projectOntoAxis(V, axis)
    proj = V' * axis;
    minProj = min(proj);
    maxProj = max(proj);
end
