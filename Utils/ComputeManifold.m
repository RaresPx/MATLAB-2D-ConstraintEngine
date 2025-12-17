function contacts = ComputeManifold(refPoly, incPoly, normal, refIndex, depth, isCircle)
% Computes up to 2 contact points between polygons or circles
%
% refPoly : 2xN reference polygon (or circle center)
% incPoly : 2xM incident polygon (or circle center)
% normal  : collision normal pointing from ref to inc
% refIndex: index of reference edge in refPoly
% depth   : penetration depth
% isCircle: true if either body is a circle

% --- Handle circle contacts separately ---
if isCircle
    % Both circles or circle-polygon
    contacts = (refPoly + incPoly)/2; % midpoint as contact
    return;
end

% --- Polygon vs Polygon ---
N = size(refPoly,2);

% Safety: clamp refIndex
refIndex = mod(refIndex-1, N) + 1;

% Reference edge
A = refPoly(:, refIndex);
B = refPoly(:, mod(refIndex, N) + 1);


% Clip incident edge
incEdges = [incPoly(:,2:end) - incPoly(:,1:end-1), incPoly(:,1) - incPoly(:,end)];
minDot = inf; incIdx = 1;
for i = 1:size(incEdges,2)
    e = incEdges(:,i);
    eN = [-e(2); e(1)]; eN = eN / norm(eN);
    d = dot(eN, normal);
    if d < minDot
        minDot = d;
        incIdx = i;
    end
end

C = incPoly(:, incIdx);
D = incPoly(:, mod(incIdx, size(incPoly,2)) + 1);

% Clip against reference edge planes
contacts1 = ClipEdge(C,D,A,B,true);
contacts2 = ClipEdge(C,D,A,B,false);
contacts = [contacts1, contacts2];

% Only keep points below penetration along normal
finalContacts = [];
for i = 1:size(contacts,2)
    if dot(contacts(:,i)-A, normal) <= depth + 1e-6
        finalContacts = [finalContacts, contacts(:,i)];
    end
end

% Limit to max 2 contacts
contacts = finalContacts(:,1:min(2,end));

end

%% ---------------- Helper Function ----------------
function clipped = ClipEdge(C,D,A,B,leftSide)
% Clips edge CD against left/right side plane of AB
e = B - A;
n = [-e(2); e(1)]; n = n / norm(n);
if ~leftSide, n = -n; end

distC = dot(n, C-A);
distD = dot(n, D-A);

clipped = [];
if distC <= 0, clipped = [clipped, C]; end
if distD <= 0, clipped = [clipped, D]; end

if distC*distD < 0
    t = distC / (distC - distD);
    P = C + t*(D-C);
    clipped = [clipped, P];
end
end