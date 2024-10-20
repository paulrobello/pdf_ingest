FROM public.ecr.aws/lambda/python:3.11

RUN --mount=type=cache,target=/var/cache/yum \
    yum update -y && \
    yum install zip  poppler-utils -y  && \
    yum clean all -y

# install dependencies
COPY requirements.txt  ${LAMBDA_TASK_ROOT}
RUN pip3 install -r ${LAMBDA_TASK_ROOT}/requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy function code
COPY src/ai_ocr/* ${LAMBDA_TASK_ROOT}/ai_ocr/
COPY src/*.py ${LAMBDA_TASK_ROOT}/


# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "handler.lambda_handler" ]
