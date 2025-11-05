function [colliding, normal, depth, refPoly, incPoly, refIndex, isCircle] = SATCollision(bodyA, bodyB)
% SATCollision - Broad phase collision detection using SAT
% Works for circles and convex polygons
%
% Outputs:
%   colliding  - boolean
%   normal     - collision normal (points from A to B)
%   depth      - penetration depth
%   refPoly    - reference polygon vertices (or circle center)
%   incPoly    - incident polygon vertices (or circle center)
%   refIndex   - reference face index
%   isCircle   - true if either body is a circle

colliding = false;
normal = [0;0];
depth = 0;
refPoly = [];
incPoly = [];
refIndex = 0;
isCircle = false;

% --- Circle vs Circle ---
if strcmp(bodyA.Shape,'circle') && strcmp(bodyB.Shape,'circle')
    delta = bodyB.Pos - bodyA.Pos;
    dist = norm(delta);
    totalR = bodyA.Radius + bodyB.Radius;
    if dist < totalR
        colliding = true;
        normal = delta / (dist + eps);
        depth = totalR - dist;
        refPoly = bodyA.Pos;
        incPoly = bodyB.Pos;
        refIndex = 1;
        isCircle = true;
    end
    return;
end

vertsA = bodyA.getVertices();
vertsB = bodyB.getVertices();

% Collect axes (normals to edges)
axesA = getEdgeNormals(vertsA);
axesB = getEdgeNormals(vertsB);
axesToTest = [axesA, axesB];

minOverlap = inf;
collisionNormal = [0;0];
refIsA = true;
refIdx = 0;

for i = 1:size(axesToTest,2)
    axis = axesToTest(:,i);
    axis = axis / norm(axis);

    projA = vertsA' * axis;
    projB = vertsB' * axis;

    minA = min(projA); maxA = max(projA);
    minB = min(projB); maxB = max(projB);

    overlap = min(maxA,maxB) - max(minA,minB);
    if overlap <= 0
        return; % Separating axis found
    end

    if overlap < minOverlap
        minOverlap = overlap;
        collisionNormal = axis;
        d = bodyB.Pos - bodyA.Pos;
        if dot(d, axis) < 0
            collisionNormal = -axis;
        end

        if i <= size(axesA,2)
            refIsA = true;
            refIdx = i;
        else
            refIsA = false;
            refIdx = i - size(axesA,2);
        end
    end
end

colliding = true;
normal = collisionNormal;
depth = minOverlap;
if refIsA
    refPoly = vertsA;
    incPoly = vertsB;
    refIndex = refIdx;
else
    refPoly = vertsB;
    incPoly = vertsA;
    refIndex = refIdx;
    normal = -normal;
end
isCircle = false;
end

% ---- Helper function ----
function normals = getEdgeNormals(verts)
edges = [verts(:,2:end)-verts(:,1:end-1), verts(:,1)-verts(:,end)];
normals = [-edges(2,:); edges(1,:)];
normals = normals ./ vecnorm(normals);
end
