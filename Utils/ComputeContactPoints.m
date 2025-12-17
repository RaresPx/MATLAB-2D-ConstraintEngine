function contacts = ComputeContactPoints(bodyA, bodyB, normal)
% ComputeContactPoints: Generates contact points between two convex shapes
% Handles circles as special cases
%
% Output: Nx7 array [pA_x, pA_y, pB_x, pB_y, penetration, normal_x, normal_y]

contacts = [];

% Detect if either body is a circle
isCircleA = strcmp(bodyA.Shape, 'circle');
isCircleB = strcmp(bodyB.Shape, 'circle');

if isCircleA && isCircleB
delta = bodyB.Pos(:) - bodyA.Pos(:);
dist = norm(delta);
rA = bodyA.Radius;
rB = bodyB.Radius;

if dist == 0
    normal = [1;0];  % arbitrary
else
    normal = delta / dist;
end

penetration = rA + rB - dist;
if penetration <= 0
    contacts = [];
    return;
end

pA = bodyA.Pos(:) + normal * rA;
pB = bodyB.Pos(:) - normal * rB;
contacts = [pA', pB', penetration, normal'];

    return;
end

if isCircleA || isCircleB
    % Circle-polygon collision
    if isCircleA
        circle = bodyA;
        poly = bodyB;
        flip = true;
    else
        circle = bodyB;
        poly = bodyA;
        flip = false;
    end
    
    verts = poly.getVertices()';  % Nx2
    verts = verts';
    
    % Project circle center onto polygon edges to find closest point
c = circle.Pos(:);          % 2x1 column
closestDist = inf;
closestP = [0;0];

N = size(verts,2);          % number of vertices = number of columns
for i = 1:N
    a = verts(:,i);                 % 2x1 column
    b = verts(:,mod(i,N)+1);        % 2x1 column
    edge = b - a;
    edgeLenSq = dot(edge, edge);
    if edgeLenSq < 1e-12
        continue; % skip degenerate edge
    end
    
    % Closest point on edge
    t = max(0, min(1, dot(c - a, edge) / edgeLenSq));
    p = a + t * edge;
    d = norm(c - p);
    if d < closestDist
        closestDist = d;
        closestP = p;
    end
end

    penetration = circle.Radius - closestDist;
    if penetration <= 0
        return;
    end
    
    n = (c - closestP);
    if norm(n) == 0
        n = [1;0];
    else
        n = n / norm(n);
    end
    
    if flip
        % Circle is bodyA, polygon is bodyB
        pA = c - n * circle.Radius;
        pB = closestP;
    else
        pA = closestP;
        pB = c - n * circle.Radius;
    end
    
    contacts = [pA', pB', penetration, n'];
    return;
end

% --- Polygon-polygon (previous code) ---
vertsA = bodyA.getVertices(); % 2xN
vertsB = bodyB.getVertices(); % 2xM

vertsA = vertsA';
vertsB = vertsB';

% Project all vertices onto the collision normal
projA = vertsA * normal(:);
projB = vertsB * normal(:);

penetration = min(projB) - max(projA);
if penetration >= 0
    return;
end

% Find contact candidates
contactPts = [];
for i = 1:size(vertsB,1)
    pB = vertsB(i,:);
    diff = vertsA - pB;
    dist = diff * normal(:);
    if dist <= 0
        contactPts(end+1,:) = pB; %#ok<AGROW>
    end
end

% Build output
for i = 1:size(contactPts,1)
    pB = contactPts(i,:);
    diffs = vertsA - pB;
    dists = diffs * normal(:);
    [~, idx] = min(abs(dists));
    pA = vertsA(idx,:);
    
    contacts(end+1,:) = [pA, pB, penetration, normal(:)']; %#ok<AGROW>
end

end
