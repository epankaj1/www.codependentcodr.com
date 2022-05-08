FROM epankaj1/codependentcodrbase:latest

WORKDIR /build

COPY . /build

RUN make publish
