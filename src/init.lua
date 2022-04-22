local Voxel = {}
Voxel.__index = Voxel

function Voxel.subtract(mainParts, cutParts, voxelSize)
	local initialVolume = 0
	local finalVolume = 0
	local finalParts = {}

	for i, part in ipairs(mainParts) do
		initialVolume += part.Size.X * part.Size.Y * part.Size.Z
	end
	for _, cutPart in ipairs(cutParts) do
		local cutCornerCF = cutPart.CFrame * CFrame.new(-cutPart.Size.X*0.5, -cutPart.Size.Y*0.5, -cutPart.Size.Z*0.5)

		finalParts = {}
		for i, part in ipairs(mainParts) do

			task.desynchronize()
			--debug.profilebegin("Solving Voxeler")
			local partVolume = part.Size.X * part.Size.Y * part.Size.Z
			local voxelVolume = voxelSize^3
			local cells = math.round(partVolume / voxelVolume)
			-- print("Cells", cells)
			if cells > 4000 then
				voxelSize *= 2
				if cells > 10000 then
					voxelSize *= 2
					if cells > 20000 then
						voxelSize *= 2
					end
				end
			end
			--get origin of grid, aka 0,0,0. There are no negative coordinates
			local startCornerCF = part.CFrame * CFrame.new(part.Size*-0.5) * CFrame.new(Vector3.new(1,1,1)*voxelSize*0.5)
			
			--get number of voxels in each dimension
			local xCount = math.round(part.Size.X/voxelSize)
			local yCount = math.round(part.Size.Y/voxelSize)
			local zCount = math.round(part.Size.Z/voxelSize)

			--get world space points to check
			local grid = {}
			local antigrid = {}
			for x=0, xCount-1 do
				for y=0, yCount-1 do
					for z=0, zCount-1 do
						local coordinates = Vector3.new(x,y,z)
						local worldPosition = (startCornerCF * CFrame.new(coordinates*voxelSize)).p
						local offset = cutCornerCF:Inverse() * CFrame.new(worldPosition)
						if not (offset.X < cutPart.Size.X and offset.X > 0
							and offset.Y < cutPart.Size.Y and offset.Y > 0
							and offset.Z < cutPart.Size.Z and offset.Z > 0) then
							grid[coordinates] = true
						end
					end
				end
			end

			local registry = {}
			local regions = {}
			for c3, _ in pairs(grid) do
				if registry[c3] == nil then
					local function try(newC3)
						if grid[newC3] ~= nil and registry[newC3] == nil then
							return true
						else
							return false
						end
					end

					--get x range
					local function tryX(newX)
						local newC3 = Vector3.new(newX, c3.Y, c3.Z)
						return try(newC3)
					end
					local xMax = c3.X
					
					while tryX(xMax+1) do
						xMax += 1
					end
					local xMin = c3.X
					while tryX(xMin-1) do
						xMin -= 1
					end

					--get y range
					local function tryXY(newY)
						for x=xMin, xMax do
							local newC3 = Vector3.new(x, newY, c3.Z)
							if not try(newC3) then
								return false
							end
						end
						return true
					end
					local yMax = c3.Y
					while tryXY(yMax+1) do
						yMax += 1
					end
					local yMin = c3.Y
					while tryXY(yMin-1) do
						yMin -= 1
					end

					--get z range
					local function tryXYZ(newZ)
						for x=xMin, xMax do
							for y=yMin, yMax do
								local newC3 = Vector3.new(x, y, newZ)
								if not try(newC3) then
									return false
								end
							end
						end
						return true
					end
					local zMax = c3.Z
					while tryXYZ(zMax+1) do
						zMax += 1
					end
					local zMin = c3.Z
					while tryXYZ(zMin-1) do
						zMin -= 1
					end

					--create region
					table.insert(regions, {Vector3.new(xMin, yMin, zMin), Vector3.new(xMax, yMax, zMax)})
					for x=xMin, xMax do
						for y=yMin, yMax do
							for z=zMin, zMax do
								registry[Vector3.new(x, y, z)] = #regions
							end
						end
					end

				end
			end
			--debug.profileend()
			task.synchronize()

			--build parts out of regions
			for j, regionList in ipairs(regions) do
				local min = regionList[1]
				local max = regionList[2]
				local bump = Vector3.new(1,1,1)*0.5
				local worldMin = (startCornerCF * CFrame.new((min-bump)*voxelSize)).p
				local worldMax = (startCornerCF * CFrame.new((max+bump)*voxelSize)).p
				local position = worldMin:Lerp(worldMax, 0.5)
		
				local finalPart = Instance.new("Part")
				finalPart.CFrame = CFrame.fromMatrix(
					position,
					startCornerCF.XVector,
					startCornerCF.YVector,
					startCornerCF.ZVector
				)
				finalPart.Size = ((max - min)+Vector3.new(1,1,1))*voxelSize
				finalVolume += finalPart.Size.X * finalPart.Size.Y * finalPart.Size.Z
				table.insert(finalParts, finalPart)
			end
			
		end
		mainParts = finalParts
	end

	return finalParts, math.max(initialVolume-finalVolume, 0)
end

return Voxel