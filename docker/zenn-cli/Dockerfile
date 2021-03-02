FROM node:alpine

WORKDIR /zenn
RUN npm install zenn-cli
EXPOSE 8000

ENTRYPOINT ["npx", "zenn"]
CMD ["preview"]
