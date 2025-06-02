# Use an official Node.js runtime as a parent image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package.json only
COPY package.json ./

# Install serve to serve static files
RUN npm install -g serve

# Copy the static files
COPY . .

# Expose port 3000
EXPOSE 3000

# Command to serve the static files
CMD ["serve", "-s", ".", "-l", "3000"]
