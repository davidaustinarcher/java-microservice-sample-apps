FROM node:10

WORKDIR /app
COPY src ./

RUN npm install
EXPOSE 3000

ENTRYPOINT ["node","server.js"]
